// ============================================================
// ob_feeder_live.cpp — SITARAM Live Bybit Demo WebSocket Feeder
//
// Connects to Bybit DEMO WebSocket and streams BTCUSDT
// orderbook.200 data → converts to Verilog pipe format
//
// Compile:
//   g++ -o ob_feeder_live ob_feeder_live.cpp \
//       -I/root/websocketpp \
//       -I/root/json/include \
//       -lssl -lcrypto -lboost_system -lpthread \
//       -std=c++17 -O2
//
// Run:
//   ./ob_feeder_live > input_pipe.txt
//   OR pipe directly to ModelSim
// ============================================================

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <map>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <algorithm>
#include <atomic>
#include <mutex>
#include <thread>
#include <chrono>

// WebSocket++ headers
#include <websocketpp/config/asio_client.hpp>
#include <websocketpp/client.hpp>

// nlohmann JSON
#include <nlohmann/json.hpp>

using json   = nlohmann::json;
using client = websocketpp::client<websocketpp::config::asio_tls_client>;
using context_ptr = websocketpp::lib::shared_ptr<websocketpp::lib::asio::ssl::context>;

// ── Fixed-point scaling ───────────────────────────────────────────────────────
static const int PRICE_SCALE = 10;       // 1 decimal → x10
static const int QTY_SCALE   = 1000000;  // 6 decimals → x1000000
static const int OB_LEVELS   = 200;

// ── Bybit Demo WebSocket URL ──────────────────────────────────────────────────
static const std::string WS_URL =
    "wss://stream.bybit.com/v5/public/linear";

// ── Subscribe message ─────────────────────────────────────────────────────────
static const std::string SUBSCRIBE_MSG =
    R"({"op":"subscribe","args":["orderbook.200.BTCUSDT"]})";

// ── Order book level ─────────────────────────────────────────────────────────
struct Level {
    double   price;
    double   qty;
    uint32_t price_scaled;
    uint32_t qty_scaled;
};

// ── Global orderbook state ────────────────────────────────────────────────────
std::map<double, double, std::greater<double>> g_bids; // price→qty, desc
std::map<double, double>                        g_asks; // price→qty, asc
std::mutex   g_ob_mutex;
std::atomic<int>  g_tick_num{0};
std::atomic<bool> g_running{true};

// ── Scale helpers ─────────────────────────────────────────────────────────────
uint32_t scale_price(double p) {
    return static_cast<uint32_t>(std::round(p * PRICE_SCALE));
}
uint32_t scale_qty(double q) {
    return static_cast<uint32_t>(std::round(q * QTY_SCALE));
}

// ── Write one tick to stdout ──────────────────────────────────────────────────
void write_tick(const std::map<double, double, std::greater<double>>& bids,
                const std::map<double, double>& asks)
{
    int tick = ++g_tick_num;
    std::cout << "TICK " << tick << "\n";

    // Write 200 bids
    int count = 0;
    for (auto& [price, qty] : bids) {
        if (count >= OB_LEVELS) break;
        std::cout << "BID "
                  << scale_price(price) << " "
                  << scale_qty(qty)     << "\n";
        count++;
    }
    // Pad if fewer than 200
    while (count < OB_LEVELS) {
        std::cout << "BID 0 0\n";
        count++;
    }

    // Write 200 asks
    count = 0;
    for (auto& [price, qty] : asks) {
        if (count >= OB_LEVELS) break;
        std::cout << "ASK "
                  << scale_price(price) << " "
                  << scale_qty(qty)     << "\n";
        count++;
    }
    // Pad if fewer than 200
    while (count < OB_LEVELS) {
        std::cout << "ASK 0 0\n";
        count++;
    }

    std::cout << "END\n";
    std::cout.flush();

    // Log to stderr (so stdout stays clean for Verilog pipe)
    double best_bid = bids.empty()  ? 0.0 : bids.begin()->first;
    double best_ask = asks.empty()  ? 0.0 : asks.begin()->first;
    double spread   = best_ask - best_bid;

    std::cerr << "[TICK " << std::setw(5) << tick << "] "
              << "Bid=$" << std::fixed << std::setprecision(1) << best_bid
              << " Ask=$" << best_ask
              << " Spread=$" << std::setprecision(1) << spread
              << " Bids=" << bids.size()
              << " Asks=" << asks.size()
              << "\n";
}

// ── Process snapshot ──────────────────────────────────────────────────────────
void process_snapshot(const json& data) {
    std::lock_guard<std::mutex> lock(g_ob_mutex);
    g_bids.clear();
    g_asks.clear();

    for (auto& entry : data["b"]) {
        double price = std::stod(entry[0].get<std::string>());
        double qty   = std::stod(entry[1].get<std::string>());
        if (qty > 0) g_bids[price] = qty;
    }
    for (auto& entry : data["a"]) {
        double price = std::stod(entry[0].get<std::string>());
        double qty   = std::stod(entry[1].get<std::string>());
        if (qty > 0) g_asks[price] = qty;
    }

    std::cerr << "[SNAPSHOT] bids=" << g_bids.size()
              << " asks=" << g_asks.size() << "\n";
    write_tick(g_bids, g_asks);
}

// ── Process delta ─────────────────────────────────────────────────────────────
void process_delta(const json& data) {
    std::lock_guard<std::mutex> lock(g_ob_mutex);

    // Update bids
    for (auto& entry : data["b"]) {
        double price = std::stod(entry[0].get<std::string>());
        double qty   = std::stod(entry[1].get<std::string>());
        if (qty == 0.0)
            g_bids.erase(price);
        else
            g_bids[price] = qty;
    }
    // Update asks
    for (auto& entry : data["a"]) {
        double price = std::stod(entry[0].get<std::string>());
        double qty   = std::stod(entry[1].get<std::string>());
        if (qty == 0.0)
            g_asks.erase(price);
        else
            g_asks[price] = qty;
    }

    write_tick(g_bids, g_asks);
}

// ── TLS init ──────────────────────────────────────────────────────────────────
context_ptr on_tls_init(websocketpp::connection_hdl) {
    auto ctx = websocketpp::lib::make_shared<
                   websocketpp::lib::asio::ssl::context>(
                   websocketpp::lib::asio::ssl::context::tlsv12_client);
    ctx->set_verify_mode(websocketpp::lib::asio::ssl::verify_none);
    return ctx;
}

// ── On open: subscribe ────────────────────────────────────────────────────────
void on_open(client* c, websocketpp::connection_hdl hdl) {
    std::cerr << "[WS] Connected to Bybit Demo\n";
    std::cerr << "[WS] Subscribing to orderbook.200.BTCUSDT...\n";
    c->send(hdl, SUBSCRIBE_MSG, websocketpp::frame::opcode::text);
}

// ── On message: parse and process ────────────────────────────────────────────
void on_message(client* c, websocketpp::connection_hdl hdl,
                client::message_ptr msg)
{
    try {
        auto j = json::parse(msg->get_payload());

        // Handle subscription confirmation
        if (j.contains("op") && j["op"] == "subscribe") {
            std::cerr << "[WS] Subscription confirmed: "
                      << j.dump() << "\n";
            return;
        }

        // Handle ping/pong
        if (j.contains("op") && j["op"] == "ping") {
            c->send(hdl,
                    R"({"op":"pong"})",
                    websocketpp::frame::opcode::text);
            return;
        }

        // Handle orderbook data
        if (j.contains("topic") &&
            j["topic"] == "orderbook.200.BTCUSDT") {

            std::string type = j["type"].get<std::string>();
            auto& data = j["data"];

            if (type == "snapshot") {
                process_snapshot(data);
            } else if (type == "delta") {
                process_delta(data);
            }
        }

    } catch (const std::exception& e) {
        std::cerr << "[ERROR] Message parse failed: " << e.what() << "\n";
    }
}

// ── On close ─────────────────────────────────────────────────────────────────
void on_close(client* c, websocketpp::connection_hdl hdl) {
    std::cerr << "[WS] Connection closed\n";
    g_running = false;
}

// ── On fail ───────────────────────────────────────────────────────────────────
void on_fail(client* c, websocketpp::connection_hdl hdl) {
    auto con = c->get_con_from_hdl(hdl);
    std::cerr << "[WS] Connection FAILED: "
              << con->get_ec().message() << "\n";
    g_running = false;
}

// ── Heartbeat thread (ping every 20s to keep connection alive) ───────────────
void heartbeat_thread(client* c, websocketpp::connection_hdl hdl) {
    while (g_running) {
        std::this_thread::sleep_for(std::chrono::seconds(20));
        if (!g_running) break;
        try {
            c->send(hdl,
                    R"({"op":"ping"})",
                    websocketpp::frame::opcode::text);
            std::cerr << "[WS] Ping sent\n";
        } catch (...) {
            std::cerr << "[WS] Ping failed\n";
        }
    }
}

// ── Main ─────────────────────────────────────────────────────────────────────
int main() {
    std::cerr << "================================================\n";
    std::cerr << "  SITARAM Live Bybit Demo OB Feeder\n";
    std::cerr << "  URL: " << WS_URL << "\n";
    std::cerr << "  Symbol: BTCUSDT | Depth: 200\n";
    std::cerr << "  Price scale: x" << PRICE_SCALE << "\n";
    std::cerr << "  Qty scale:   x" << QTY_SCALE   << "\n";
    std::cerr << "================================================\n\n";

    client ws_client;

    try {
        // Set logging to errors only
        ws_client.set_access_channels(websocketpp::log::alevel::none);
        ws_client.set_error_channels(websocketpp::log::elevel::fatal);

        ws_client.init_asio();
        ws_client.set_tls_init_handler(on_tls_init);

        ws_client.set_open_handler(
            [&ws_client](websocketpp::connection_hdl hdl) {
                on_open(&ws_client, hdl);

                // Start heartbeat in background thread
                std::thread hb(heartbeat_thread, &ws_client, hdl);
                hb.detach();
            });

        ws_client.set_message_handler(
            [&ws_client](websocketpp::connection_hdl hdl,
                         client::message_ptr msg) {
                on_message(&ws_client, hdl, msg);
            });

        ws_client.set_close_handler(
            [&ws_client](websocketpp::connection_hdl hdl) {
                on_close(&ws_client, hdl);
            });

        ws_client.set_fail_handler(
            [&ws_client](websocketpp::connection_hdl hdl) {
                on_fail(&ws_client, hdl);
            });

        websocketpp::lib::error_code ec;
        auto con = ws_client.get_connection(WS_URL, ec);
        if (ec) {
            std::cerr << "[ERROR] Connection init failed: "
                      << ec.message() << "\n";
            return 1;
        }

        ws_client.connect(con);

        std::cerr << "[WS] Connecting...\n";
        ws_client.run();  // blocks until connection closes

    } catch (const std::exception& e) {
        std::cerr << "[FATAL] " << e.what() << "\n";
        return 1;
    }

    std::cerr << "\n[Done] Total ticks: " << g_tick_num << "\n";
    return 0;
}
