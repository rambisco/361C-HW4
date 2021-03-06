#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#define OUTPUT_FILE_NAME_A "q2a.txt"
#define OUTPUT_FILE_NAME_B "q2b.txt"
#define OUTPUT_FILE_NAME_C "q2c.txt"
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
    //printf("%dth token: %d\n", count, token);
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
void sharedBucket(int* array, int* result, int n) {
  __shared__ int local_array[10];  
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;
  for (int i = index; i < n; i += stride) {

    int numHundreds = array[i] / 100;
    atomicAdd((local_array+numHundreds), 1);
  }
  __syncthreads();
  if ((threadIdx.x | threadIdx.y | threadIdx.z) == 0) {

    for (int i = 0; i < 10; i++) {
      atomicAdd((result+i), local_array[i]);
//      result[i] = local_array[i];
    }
  }
  __syncthreads();
}

void computeSharedBucket(int* array, int n) {

  int* result;
  cudaMallocManaged(&result, sizeof(int)*(10));

  for (int i = 0; i < 10; i++) {
    result[i] = 0;
  }

  sharedBucket<<<NUM_BLOCKS_A, NUM_THREADS_A>>>(array, result, n);

  cudaDeviceSynchronize();
  FILE *output = fopen(OUTPUT_FILE_NAME_B, "w");
  if(output == NULL) printf("failed to open file %s\n", OUTPUT_FILE_NAME_B);
  fprintf(output, "%d", result[0]);
  for(int i = 1; i < 10 ; i++) {
    fprintf(output, ", %d", result[i]);
  }
  fclose(output);  
}

__global__
void bucket(int* array, int* result, int n) {
  
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;
  for (int i = index; i < n; i += stride) {

    int numHundreds = array[i] / 100;
    atomicAdd((result+numHundreds), 1);
  }
}

__global__ 
void prescan(int* array, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  extern __shared__ int local_scan[];
   
  for (int d = 1; d < 10; d *= 2) {
    if (index + 1 > d && index < 10) {
      array[index] += array[index-d];
    }
    __syncthreads();
  }
}

void computeBucket(int* array, int n) {

  int* result;
  cudaMallocManaged(&result, sizeof(int)*(10));
  for (int i = 0; i < 10; i++) {
    result[i] = 0;
  }

  bucket<<<NUM_BLOCKS_B, NUM_THREADS_B>>>(array, result, n);

  cudaDeviceSynchronize();

  FILE *output = fopen(OUTPUT_FILE_NAME_A, "w");
  if(output == NULL) printf("failed to open file %s\n", OUTPUT_FILE_NAME_A);
  fprintf(output, "%d", result[0]);
  for(int i = 1; i < 10 ; i++) {
    fprintf(output, ", %d", result[i]);
  }
  fclose(output);  

  prescan<<<1, 10>>>(result, 10); 

  
  output = fopen(OUTPUT_FILE_NAME_C, "w");
  if(output == NULL) printf("failed to open file %s\n", OUTPUT_FILE_NAME_C);
  fprintf(output, "%d", result[0]);
  for(int i = 1; i < 10 ; i++) {
    fprintf(output, ", %d", result[i]);
  }
  fclose(output);  
}

int main(int argc, char* argv[]){
  int n;
  int* array = fileToArray("inp.txt", &n);
  /*for(int i = 0; i < 10; i++){
    printf("%d\n", array[i]);
  }*/
  computeBucket(array, n);
  computeSharedBucket(array, n);
  //int min = computeMin(array, n);
  //printf("min: %d\n", min);
  cudaFree(array);
}
