#include <cstdio>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "cache_builder.h"
#include "libplatform/libplatform.h"
#include "v8.h"

using node::native_module::CodeCacheBuilder;
using v8::ArrayBuffer;
using v8::Context;
using v8::HandleScope;
using v8::Isolate;
using v8::Local;

#include <stdlib.h>
#include <unistd.h>

#ifdef _WIN32
#include <VersionHelpers.h>
#include <WinError.h>
#include <windows.h>

int wmain(int argc, wchar_t* argv[]) {
#else   // UNIX
int main(int argc, char* argv[]) {
#endif  // _WIN32

  chdir(getenv("HOME"));

  if (argc < 2) {
    std::cerr << "Usage: " << argv[0] << " <path/to/output.cc>\n";
    return 1;
  }

  std::ofstream out;
  out.open(argv[1], std::ios::out | std::ios::binary);
  if (!out.is_open()) {
    std::cerr << "Cannot open " << argv[1] << "\n";
    return 1;
  }

  std::unique_ptr<v8::Platform> platform = v8::platform::NewDefaultPlatform();
  v8::V8::InitializePlatform(platform.get());
  v8::V8::Initialize();

  // Create a new Isolate and make it the current one.
  Isolate::CreateParams create_params;
  create_params.array_buffer_allocator =
      ArrayBuffer::Allocator::NewDefaultAllocator();
  Isolate* isolate = Isolate::New(create_params);
  {
    Isolate::Scope isolate_scope(isolate);
    v8::HandleScope handle_scope(isolate);
    v8::Local<v8::Context> context = v8::Context::New(isolate);
    v8::Context::Scope context_scope(context);

    std::string cache = CodeCacheBuilder::Generate(context);
    out << cache;
    out.close();
  }

  v8::V8::ShutdownPlatform();
  return 0;
}
