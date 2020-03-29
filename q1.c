#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>


void* fileToArray(char file1[], int* n){
  FILE* fptr = fopen(file1, "r");
  char* str = malloc(sizeof(char)*2048);
  int token;
  fscanf(fptr, "%d,", n);
  //int* array = malloc(sizeof(int)*(*n));
  cudaMallocManaged(&array, sizeof(int)*(*n)); 
  for(int i = 0; i < *n; i++){
    fscanf(fptr, "%d,", &token);
    array[i] = token;
  }
 fclose(fptr);
 return array;
}

int computeMin(int* array, int n){

  int numThreads = 1;
  int numBlocks = 1;
  min<<<numBlocks, numThreads>>>(array, n);

  cudaDeviceSynchronize();

  int min = INT_MAX;
  for(int i = 0; i < numThreads; i++){
    if(array[i] < min){
      min = array[i];
    }
  }
  return min;
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

int main(int argc, char* argv[]){
  int n;
  int* array = fileToArray("inp.txt", &n);
  for(int i = 0; i < 10; i++){
    printf("%d\n", array[i]);
  }
  int min = computeMin(array, n);
  printf("min: %d\n", min);
  cudaFree(array);
}