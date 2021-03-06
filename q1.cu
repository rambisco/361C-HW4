#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>


#define OUTPUT_FILE_NAME_B "q1b.txt"
#define OUTPUT_FILE_NAME_MIN "q1a.txt"
#define NUM_THREADS_A 32
#define NUM_BLOCKS_A 2
#define NUM_THREADS_B 32
#define NUM_BLOCKS_B 2
// int* fileToArray(char file1[], int* n){
//   FILE* fptr = fopen(file1, "r");
//   char* str = (char*) malloc(sizeof(char)*2048);
//   int token;
//   fscanf(fptr, "%d,", n);
//   int* array;
//   //int* array = malloc(sizeof(int)*(*n));
//   cudaMallocManaged(&array, sizeof(int)*(*n)); 
//   for(int i = 0; i < *n; i++){
//     fscanf(fptr, "%d,", &token);
//     array[i] = token;
//   }
//  fclose(fptr);
//  return array;
// }

int* fileToArray(char file1[], int* n){
  FILE* fptr = fopen(file1, "r");
  char* str = (char*) malloc(sizeof(char)*2048);
  int token;
  int count = 0;
  while (fscanf(fptr, "%d, ", &token) != EOF) {
    //("%dth token: %d\n", count, token);
    count++;
  }
  *n = count;
  //printf("total number of elements: %d\n", *n);
  int* array;
  cudaMallocManaged(&array, sizeof(int)*(*n));
  rewind(fptr);
  for(int i = 0; i < *n; i++){
      fscanf(fptr, "%d, ", &token);
      array[i] = token;
  }

  fclose(fptr);
  return array;
}
__global__
void lastDigit(int* array, int* result, int n) {
  
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;
  for (int i = index; i < n; i += stride) {
    result[i] = array[i] % 10;
  }
}

__global__
void min(int* array, int n){

  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;
  int currentMin = INT_MAX;
  for(int i = index; i < n; i += stride){
    if(array[i] < currentMin){
      currentMin = array[i];
    }
  }
  array[index] = currentMin;
}

int computeMin(int* array, int n){

  min<<<NUM_BLOCKS_A, NUM_THREADS_A>>>(array, n);

  cudaDeviceSynchronize();

  int minNum = INT_MAX;
  for(int i = 0; i < NUM_THREADS_A; i++){
    if(array[i] < minNum){
      minNum = array[i];
    }
  }
  return minNum;
}

void computeLastDigit(int* array, int n) {
  int* result;
  cudaMallocManaged(&result, sizeof(int)*(n));
  lastDigit<<<NUM_BLOCKS_B, NUM_THREADS_B>>>(array, result, n);

  cudaDeviceSynchronize();
  // for (int i = 0; i < 10; i++) {
  //   printf("array[%d]: %d, result[%d]: %d\n", i, array[i], i, result[i]);
  // }
  FILE *output = fopen(OUTPUT_FILE_NAME_B, "w");
  if(output == NULL) printf("failed to open file %s\n", OUTPUT_FILE_NAME_B);
  fprintf(output, "%d", result[0]);
  for(int i = 1; i < n ; i++) {
    fprintf(output, ", %d", result[i]);
  }
  fclose(output);
}

int main(int argc, char* argv[]){
  int n;
  int* array = fileToArray("inp.txt", &n);
  //printf("Number of elements in array: %d\n", n);
  // for (int i = 0; i < n; i++) {
  //   printf("%d, ", array[i]);
  // }
  /*for(int i = 0; i < 10; i++){
    printf("%d\n", array[i]);
  }*/
  computeLastDigit(array, n);
  int min = computeMin(array, n);
  
  FILE *output = fopen(OUTPUT_FILE_NAME_MIN, "w");
  if(output == NULL) printf("failed to open file %s\n", OUTPUT_FILE_NAME_MIN);
  fprintf(output, "%d", min);
  fclose(output);
  cudaFree(array);
}
