// ============================================================
// ob_feeder.cpp — C++ Data Feeder for SITARAM OB Processor
//
// Reads Bybit BTCUSDT orderbook data (JSON format) and
// writes scaled fixed-point values to stdout pipe for Verilog
//
// Compile: g++ -o ob_feeder ob_feeder.cpp -std=c++17
// Usage:   ./ob_feeder <input.data > input_pipe.txt
//          OR
//          ./ob_feeder live    (connects to Bybit WebSocket)
//
// Output format per tick:
//   TICK <n>
//   BID <price_x10> <qty_x1000000>   × 200
//   ASK <price_x10> <qty_x1000000>   × 200
//   END
//
// Price scaling: $66970.6 → 669706  (x10, 1 decimal place)
// Qty scaling:   0.055649 → 55649   (x1000000, 6 decimal places)
// ============================================================

#include <iostream>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <cmath>
#include <cstdint>
#include <iomanip>
#include <algorithm>

// ── Fixed-point scaling constants ────────────────────────────────────────────
static const int    PRICE_SCALE  = 10;       // 1 decimal place
static const int    QTY_SCALE    = 1000000;  // 6 decimal places
static const int    OB_LEVELS    = 200;      // levels per side

// ── Order book entry ─────────────────────────────────────────────────────────
struct Level {
    double price;
    double qty;
    uint32_t price_scaled;   // price * PRICE_SCALE
    uint32_t qty_scaled;     // qty   * QTY_SCALE
};

// ── Scale a price string to integer ──────────────────────────────────────────
uint32_t scale_price(const std::string& s) {
    double p = std::stod(s);
    return static_cast<uint32_t>(std::round(p * PRICE_SCALE));
}

// ── Scale a quantity string to integer ───────────────────────────────────────
uint32_t scale_qty(const std::string& s) {
    double q = std::stod(s);
    return static_cast<uint32_t>(std::round(q * QTY_SCALE));
}

// ── Simple JSON array parser for [["price","qty"],...] ───────────────────────
std::vector<Level> parse_levels(const std::string& json_array) {
    std::vector<Level> levels;
    size_t pos = 0;

    while ((pos = json_array.find('[', pos)) != std::string::npos) {
        size_t close = json_array.find(']', pos);
        if (close == std::string::npos) break;

        std::string pair = json_array.substr(pos + 1, close - pos - 1);
        // pair = "\"66970.6\",\"0.055649\""
        size_t q1 = pair.find('"');
        size_t q2 = pair.find('"', q1 + 1);
        size_t q3 = pair.find('"', q2 + 1);
        size_t q4 = pair.find('"', q3 + 1);

        if (q1 != std::string::npos && q4 != std::string::npos) {
            std::string price_str = pair.substr(q1 + 1, q2 - q1 - 1);
            std::string qty_str   = pair.substr(q3 + 1, q4 - q3 - 1);

            if (!price_str.empty() && !qty_str.empty()) {
                Level lv;
                lv.price         = std::stod(price_str);
                lv.qty           = std::stod(qty_str);
                lv.price_scaled  = scale_price(price_str);
                lv.qty_scaled    = scale_qty(qty_str);
                levels.push_back(lv);
            }
        }
        pos = close + 1;
    }
    return levels;
}

// ── Write one tick to stdout in Verilog pipe format ───────────────────────────
void write_tick(int tick_num,
                const std::vector<Level>& bids,
                const std::vector<Level>& asks)
{
    std::cout << "TICK " << tick_num << "\n";

    // Write 200 bids (pad with zeros if fewer available)
    for (int i = 0; i < OB_LEVELS; i++) {
        if (i < (int)bids.size()) {
            std::cout << "BID "
                      << bids[i].price_scaled << " "
                      << bids[i].qty_scaled   << "\n";
        } else {
            std::cout << "BID 0 0\n";   // padding
        }
    }

    // Write 200 asks (pad with zeros if fewer available)
    for (int i = 0; i < OB_LEVELS; i++) {
        if (i < (int)asks.size()) {
            std::cout << "ASK "
                      << asks[i].price_scaled << " "
                      << asks[i].qty_scaled   << "\n";
        } else {
            std::cout << "ASK 0 0\n";   // padding
        }
    }

    std::cout << "END\n";
    std::cout.flush();
}

// ── Process snapshot message ──────────────────────────────────────────────────
void process_snapshot(const std::string& line, int& tick_num,
                      std::vector<Level>& cur_bids,
                      std::vector<Level>& cur_asks)
{
    // Find "b":[ section
    size_t b_pos = line.find("\"b\":[");
    size_t a_pos = line.find("\"a\":[");
    if (b_pos == std::string::npos || a_pos == std::string::npos) return;

    // Extract bid array
    size_t b_end = line.find("],\"a\":", b_pos);
    std::string bid_json = line.substr(b_pos + 4, b_end - b_pos - 4);

    // Extract ask array
    size_t a_start = a_pos + 4;
    size_t a_end   = line.find("],\"u\":", a_start);
    if (a_end == std::string::npos) a_end = line.find("]}", a_start);
    std::string ask_json = line.substr(a_start, a_end - a_start);

    cur_bids = parse_levels(bid_json);
    cur_asks = parse_levels(ask_json);

    // Sort: bids descending (best = highest price first)
    std::sort(cur_bids.begin(), cur_bids.end(),
              [](const Level& a, const Level& b){
                  return a.price > b.price;
              });
    // Sort: asks ascending (best = lowest price first)
    std::sort(cur_asks.begin(), cur_asks.end(),
              [](const Level& a, const Level& b){
                  return a.price < b.price;
              });

    tick_num++;
    write_tick(tick_num, cur_bids, cur_asks);

    std::cerr << "[Feeder] SNAPSHOT tick=" << tick_num
              << " bids=" << cur_bids.size()
              << " asks=" << cur_asks.size()
              << " best_bid=$" << std::fixed << std::setprecision(1)
              << (cur_bids.empty() ? 0.0 : cur_bids[0].price)
              << " best_ask=$"
              << (cur_asks.empty() ? 0.0 : cur_asks[0].price)
              << "\n";
}

// ── Apply delta update to current orderbook ───────────────────────────────────
void apply_delta(const std::string& line, int& tick_num,
                 std::vector<Level>& cur_bids,
                 std::vector<Level>& cur_asks)
{
    // Find delta bid/ask sections
    size_t b_pos = line.find("\"b\":[");
    size_t a_pos = line.find("\"a\":[");
    if (b_pos == std::string::npos || a_pos == std::string::npos) return;

    size_t b_end   = line.find("],\"a\":", b_pos);
    std::string bid_delta_json = line.substr(b_pos + 4, b_end - b_pos - 4);

    size_t a_start = a_pos + 4;
    size_t a_end   = line.find("],\"u\":", a_start);
    if (a_end == std::string::npos) a_end = line.find("]}", a_start);
    std::string ask_delta_json = line.substr(a_start, a_end - a_start);

    std::vector<Level> bid_deltas = parse_levels(bid_delta_json);
    std::vector<Level> ask_deltas = parse_levels(ask_delta_json);

    // ── Apply bid deltas ──────────────────────────────────────────────────
    for (auto& delta : bid_deltas) {
        bool found = false;
        for (auto& lv : cur_bids) {
            if (std::abs(lv.price - delta.price) < 0.01) {
                if (delta.qty == 0.0) {
                    lv.qty = 0.0;  // mark for removal
                } else {
                    lv.qty         = delta.qty;
                    lv.qty_scaled  = delta.qty_scaled;
                }
                found = true;
                break;
            }
        }
        if (!found && delta.qty > 0.0) {
            cur_bids.push_back(delta);
        }
    }
    // Remove zero-qty bids
    cur_bids.erase(std::remove_if(cur_bids.begin(), cur_bids.end(),
                   [](const Level& l){ return l.qty <= 0.0; }),
                   cur_bids.end());

    // ── Apply ask deltas ──────────────────────────────────────────────────
    for (auto& delta : ask_deltas) {
        bool found = false;
        for (auto& lv : cur_asks) {
            if (std::abs(lv.price - delta.price) < 0.01) {
                if (delta.qty == 0.0) {
                    lv.qty = 0.0;
                } else {
                    lv.qty        = delta.qty;
                    lv.qty_scaled = delta.qty_scaled;
                }
                found = true;
                break;
            }
        }
        if (!found && delta.qty > 0.0) {
            cur_asks.push_back(delta);
        }
    }
    // Remove zero-qty asks
    cur_asks.erase(std::remove_if(cur_asks.begin(), cur_asks.end(),
                   [](const Level& l){ return l.qty <= 0.0; }),
                   cur_asks.end());

    // ── Re-sort ───────────────────────────────────────────────────────────
    std::sort(cur_bids.begin(), cur_bids.end(),
              [](const Level& a, const Level& b){ return a.price > b.price; });
    std::sort(cur_asks.begin(), cur_asks.end(),
              [](const Level& a, const Level& b){ return a.price < b.price; });

    tick_num++;
    write_tick(tick_num, cur_bids, cur_asks);

    std::cerr << "[Feeder] DELTA tick=" << tick_num
              << " best_bid=$" << std::fixed << std::setprecision(1)
              << (cur_bids.empty() ? 0.0 : cur_bids[0].price)
              << " best_ask=$"
              << (cur_asks.empty() ? 0.0 : cur_asks[0].price)
              << " spread=$" << std::setprecision(1)
              << (cur_asks.empty() || cur_bids.empty() ? 0.0 :
                  cur_asks[0].price - cur_bids[0].price)
              << "\n";
}

// ── Main: read .data file line by line ───────────────────────────────────────
int main(int argc, char* argv[]) {
    std::istream* in_stream = &std::cin;
    std::ifstream file_stream;

    if (argc > 1 && std::string(argv[1]) != "live") {
        file_stream.open(argv[1]);
        if (!file_stream.is_open()) {
            std::cerr << "ERROR: Cannot open file: " << argv[1] << "\n";
            return 1;
        }
        in_stream = &file_stream;
        std::cerr << "[Feeder] Reading from file: " << argv[1] << "\n";
    } else {
        std::cerr << "[Feeder] Reading from stdin (pipe mode)\n";
    }

    std::cerr << "[Feeder] SITARAM BTCUSDT OB Feeder started\n";
    std::cerr << "[Feeder] Price scale: x" << PRICE_SCALE << "\n";
    std::cerr << "[Feeder] Qty scale:   x" << QTY_SCALE   << "\n";
    std::cerr << "[Feeder] OB levels:   " << OB_LEVELS    << "\n\n";

    std::vector<Level> cur_bids, cur_asks;
    int tick_num = 0;
    std::string line;

    while (std::getline(*in_stream, line)) {
        if (line.empty()) continue;

        // Detect snapshot
        if (line.find("\"type\":\"snapshot\"") != std::string::npos) {
            process_snapshot(line, tick_num, cur_bids, cur_asks);
        }
        // Detect delta
        else if (line.find("\"type\":\"delta\"") != std::string::npos) {
            apply_delta(line, tick_num, cur_bids, cur_asks);
        }
    }

    std::cerr << "\n[Feeder] Done. Total ticks generated: " << tick_num << "\n";
    return 0;
}
