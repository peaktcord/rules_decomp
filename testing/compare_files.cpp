#include <cstdlib>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>

namespace {

std::filesystem::path resolve_runfile(const char* argument) {
  std::filesystem::path direct(argument);
  if (std::filesystem::exists(direct)) return direct;

  std::string wanted = direct.lexically_normal().generic_string();
  if (wanted.rfind("./", 0) == 0) wanted.erase(0, 2);
  const char* workspace = std::getenv("TEST_WORKSPACE");
  const std::string logical =
      (workspace ? std::string(workspace) : "_main") + "/" + wanted;

  if (const char* directory = std::getenv("RUNFILES_DIR")) {
    std::filesystem::path candidate =
        std::filesystem::path(directory) / logical;
    if (std::filesystem::exists(candidate)) return candidate;
  }

  const char* manifest = std::getenv("RUNFILES_MANIFEST_FILE");
  if (!manifest) return direct;
  std::ifstream entries(manifest);
  std::string line;
  while (std::getline(entries, line)) {
    if (!line.empty() && line.back() == '\r') line.pop_back();
    const std::size_t split = line.find(' ');
    if (split == std::string::npos) continue;
    const std::string key = line.substr(0, split);
    if (logical == key) return std::filesystem::path(line.substr(split + 1));
    if (logical.size() > key.size() &&
        logical.compare(0, key.size(), key) == 0 &&
        logical[key.size()] == '/') {
      return std::filesystem::path(line.substr(split + 1)) /
             logical.substr(key.size() + 1);
    }
  }
  return direct;
}

bool read_byte(std::ifstream& stream, unsigned char& value) {
  char raw = 0;
  if (!stream.get(raw)) return false;
  value = static_cast<unsigned char>(raw);
  return true;
}

}  // namespace

int main(int argc, char** argv) {
  if (argc != 3) {
    std::cerr << "usage: compare_files ACTUAL EXPECTED\n";
    return 2;
  }
  const std::filesystem::path actual_path = resolve_runfile(argv[1]);
  const std::filesystem::path expected_path = resolve_runfile(argv[2]);
  std::ifstream actual(actual_path, std::ios::binary);
  std::ifstream expected(expected_path, std::ios::binary);
  if (!actual || !expected) {
    std::cerr << "could not open comparison inputs: " << actual_path << " and "
              << expected_path << "\n";
    return 2;
  }

  std::uint64_t offset = 0;
  while (true) {
    unsigned char actual_byte = 0;
    unsigned char expected_byte = 0;
    const bool have_actual = read_byte(actual, actual_byte);
    const bool have_expected = read_byte(expected, expected_byte);
    if (!have_actual || !have_expected) {
      if (have_actual != have_expected) {
        std::cerr << "file lengths differ at byte " << offset << "\n";
        return 1;
      }
      return 0;
    }
    if (actual_byte != expected_byte) {
      std::cerr << "files differ at byte " << offset << ": actual=0x"
                << std::hex << static_cast<unsigned int>(actual_byte)
                << " expected=0x" << static_cast<unsigned int>(expected_byte)
                << "\n";
      return 1;
    }
    ++offset;
  }
}
