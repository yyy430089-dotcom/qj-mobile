#ifndef QJMOBILE_H
#define QJMOBILE_H
#include <stdint.h>
// 所有路径和 JSON 都是 UTF-8、以 NUL 结尾。会话可跨线程，但调用按序执行。
uint64_t qjm_create(const char *dictionary_path, const char *glossary_path);
// 返回 JSON 字符串；调用方必须用 qjm_string_free 释放。
char *qjm_dispatch(uint64_t session, const char *command_json);
void qjm_destroy(uint64_t session);
void qjm_string_free(char *value);
#endif
