#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#define NUM_THREADS 32
#define NUM_BLOCKS 2

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
void countOdds(int* array, int* result, int n) {
  
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;
  for (int i = index; i < n; i += stride) {
    atomicAdd(result, 1);
  }
}

__global__
void odds(int* array, int* result, int n){
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  int stride = blockDim.x * gridDim.x;
  for (int i = index; i < n; i += stride) {
    atomicAdd(result, 1);
  }


}

void copyOdds(int* array, int n) {

  int* result;
  cudaMallocManaged(&result, sizeof(int));


  countOdds<<<NUM_BLOCKS, NUM_THREADS>>>(array, result, n);
  cudaDeviceSynchronize();




}

int main(int argc, char* argv[]){
  int n;
  int* array = fileToArray("inp.txt", &n);
  copyOdds(array, n);
  //int min = computeMin(array, n);
  //printf("min: %d\n", min);
  cudaFree(array);
}