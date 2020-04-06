#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#define NUM_THREADS_A 32
#define NUM_BLOCKS_A 2
#define NUM_THREADS_B 32
#define NUM_BLOCKS_B 2

int* fileToArray(char file1[], int* n){
  FILE* fptr = fopen(file1, "r");
  char* str = (char*) malloc(sizeof(char)*2048);
  int token;
  fscanf(fptr, "%d,", n);
  int* array;
  //int* array = malloc(sizeof(int)*(*n));
  cudaMallocManaged(&array, sizeof(int)*(*n)); 
  for(int i = 0; i < *n; i++){
    fscanf(fptr, "%d,", &token);
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
  for (int i = 0; i < 10; i++) {
    printf("result[%d]: %d\n", i, result[i]);
  }
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

void computeBucket(int* array, int n) {

  int* result;
  cudaMallocManaged(&result, sizeof(int)*(10));

  for (int i = 0; i < 10; i++) {
    result[i] = 0;
  }

  bucket<<<NUM_BLOCKS_B, NUM_THREADS_B>>>(array, result, n);

  cudaDeviceSynchronize();
  for (int i = 0; i < 10; i++) {
    printf("result[%d]: %d\n", i, result[i]);
  }
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
