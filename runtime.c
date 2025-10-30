
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>

typedef struct {
  int32_t length;
  int32_t capacity; // default: length * 2 + 1
  int32_t *data;
} IntArray;

typedef struct {
  int32_t length;
  int32_t capacity; // default: length * 2 + 1
  double *data;
} DoubleArray;

typedef struct {
  int32_t length;
  int32_t capacity; // default: length * 2 + 1
  uint8_t *data;
} BoolArray;

typedef struct {
  int32_t length;
  int32_t capacity; // default: length * 2 + 1
  void **data;
} PtrArray;

typedef struct {
  char *data;
  int32_t length;
} MoonBitStr;

IntArray* make_int_array(int32_t length, int32_t init_value) {
  IntArray *arr = (IntArray *)malloc(sizeof(IntArray));
  arr->length = length;
  arr->capacity = length * 2 + 1;
  arr->data = (int32_t *)malloc(arr->capacity * sizeof(int32_t));
  for (int32_t i = 0; i < length; i++) {
    arr->data[i] = init_value;
  }
  return arr;
}

DoubleArray* make_double_array(int32_t length, double init_value) {
  DoubleArray *arr = (DoubleArray *)malloc(sizeof(DoubleArray));
  arr->length = length;
  arr->capacity = length * 2 + 1;
  arr->data = (double *)malloc(arr->capacity * sizeof(double));
  for (int32_t i = 0; i < length; i++) {
    arr->data[i] = init_value;
  }
  return arr;
}

BoolArray* make_bool_array(int32_t length, uint8_t init_value) {
  BoolArray *arr = (BoolArray *)malloc(sizeof(BoolArray));
  arr->length = length;
  arr->capacity = length * 2 + 1;
  arr->data = (uint8_t *)malloc(arr->capacity * sizeof(uint8_t));
  for (int32_t i = 0; i < length; i++) {
    arr->data[i] = init_value;
  }
  return arr;
}

PtrArray* make_ptr_array(int32_t length, void *init_value) {
  PtrArray *arr = (PtrArray *)malloc(sizeof(PtrArray));
  arr->length = length;
  arr->data = (void **)malloc(length * sizeof(void *));
  for (int32_t i = 0; i < length; i++) {
    arr->data[i] = init_value;
  }
  return arr;
}

int32_t get_array_length(void *array) {
  return *((int32_t *)array);
}

void array_int_push(IntArray *arr, int32_t value) {
  if (arr->length >= arr->capacity) {
    arr->capacity = arr->capacity * 2 + 1;
    arr->data = (int32_t *)realloc(arr->data, arr->capacity * sizeof(int32_t));
  }
  arr->data[arr->length++] = value;
}

void array_double_push(DoubleArray *arr, double value) {
  if (arr->length >= arr->capacity) {
    arr->capacity = arr->capacity * 2 + 1;
    arr->data = (double *)realloc(arr->data, arr->capacity * sizeof(double));
  }
  arr->data[arr->length++] = value;
}

void array_bool_push(BoolArray *arr, uint8_t value) {
  if (arr->length >= arr->capacity) {
    arr->capacity = arr->capacity * 2 + 1;
    arr->data = (uint8_t *)realloc(arr->data, arr->capacity * sizeof(uint8_t));
  }
  arr->data[arr->length++] = value;
}

void array_ptr_push(PtrArray *arr, void *value) {
  if (arr->length >= arr->capacity) {
    arr->capacity = arr->capacity * 2 + 1;
    arr->data = (void **)realloc(arr->data, arr->capacity * sizeof(void *));
  }
  arr->data[arr->length++] = value;
}

int array_int_get(IntArray *arr, int32_t index) {
  return arr->data[index];
}

double array_double_get(DoubleArray *arr, int32_t index) {
  return arr->data[index];
}

uint8_t array_bool_get(BoolArray *arr, int32_t index) {
  return arr->data[index];
}

void* array_ptr_get(PtrArray *arr, int32_t index) {
  return arr->data[index];
}

void array_int_put(IntArray *arr, int32_t index, int32_t value) {
  arr->data[index] = value;
}

void array_double_put(DoubleArray *arr, int32_t index, double value) {
  arr->data[index] = value;
}

void array_bool_put(BoolArray *arr, int32_t index, uint8_t value) {
  arr->data[index] = value;
}

void array_ptr_put(PtrArray *arr, int32_t index, void *value) {
  arr->data[index] = value;
}

void moonbit_main();

void print_int(int value) {
  printf("%d", value);
}

void print_bool(uint8_t value) {
  if (value) {
    printf("true");
  } else {
    printf("false");
  }
}

void print_string(MoonBitStr *str) {
  if (str == NULL || str->data == NULL) {
    return;
  }
  printf("%s", str->data);
}

void* moonbit_malloc(int32_t size) {
  return malloc(size);
}

int int_of_float(double value) {
  return (int)value;
}

double float_of_int(int32_t value) {
  return (double)value;
}

double abs_float(double value) {
  return value < 0 ? -value : value;
}

int32_t truncate(double value) {
  return (int32_t)value;
}

void print_endline() {
  printf("\n");
}

void __builtin_println_int(int value) {
  printf("%d\n", value);
}

void __builtin_println_bool(uint8_t value) {
  if (value) {
    printf("true\n");
  } else {
    printf("false\n");
  }
}

void __builtin_println_string(MoonBitStr *str) {
  if (str == NULL || str->data == NULL) {
    printf("\n");
    return;
  }
  printf("%s\n", str->data);
}

void __builtin_println_double(double value) {
  printf("%f\n", value);
}

void __builtin_print_int(int value) {
  printf("%d", value);
}

void __builtin_print_bool(uint8_t value) {
  if (value) {
    printf("true");
  } else {
    printf("false");
  }
}

void __builtin_print_string(MoonBitStr *str) {
  if (str == NULL || str->data == NULL) {
    return;
  }
  printf("%s", str->data);
}

void __builtin_print_double(double value) {
  printf("%f", value);
}

MoonBitStr* __builtin_create_string(const char* str) {
  MoonBitStr *moonbit_str = (MoonBitStr *)malloc(sizeof(MoonBitStr));
  int len = 0;
  while (str[len] != '\0') {
    len++;
  }
  moonbit_str->length = len;
  moonbit_str->data = (char *)malloc((len + 1) * sizeof(char));
  for (int i = 0; i < len; i++) {
    moonbit_str->data[i] = str[i];
  }
  moonbit_str->data[len] = '\0';
  return moonbit_str;
}

int32_t __builtin_get_string_length(MoonBitStr* str) {
  return str->length;
}

MoonBitStr* __builtin_string_concat(MoonBitStr* str1, MoonBitStr* str2) {
  MoonBitStr *result = (MoonBitStr *)malloc(sizeof(MoonBitStr));
  result->length = str1->length + str2->length;
  result->data = (char *)malloc((result->length + 1) * sizeof(char));
  for (int i = 0; i < str1->length; i++) {
    result->data[i] = str1->data[i];
  }
  for (int i = 0; i < str2->length; i++) {
    result->data[str1->length + i] = str2->data[i];
  }
  result->data[result->length] = '\0';
  return result;
}

int32_t __builtin_get_char_in_string(MoonBitStr* str, int32_t index) {
  return (int32_t)str->data[index];
}

int main() {
  moonbit_main();
  return 0;
}
