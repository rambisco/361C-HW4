#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#define NUM_THREADS 512
#define NUM_BLOCKS 1

int* fileToArray(char file1[], int* n){
    FILE* fptr = fopen(file1, "r");
    char* str = (char*) malloc(sizeof(char)*2048);
    int token;
    fscanf(fptr, "%d,", n);
    int* array;
    cudaMallocManaged(&array, sizeof(int)*(*n)); 

    for(int i = 0; i < *n; i++){
        fscanf(fptr, "%d,", &token);
        array[i] = token;
    }

    fclose(fptr);
    return array;
}

// we want to keep track of how many elements have a 0 in the current bit that is to be masked.
__global__ 
void sort(int* result, int* array, int mask, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < n) {

    // this is the relative index
    result[index] = !(array[index] & mask);
  } 
}

__global__ 
void prescan(int* result, int* indices, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  //extern __shared__ int local_scan[];
  int from = blockIdx.x * blockDim.x;
  int to = blockIdx.x * blockDim.x + blockDim.x; 
   
  for (int d = 1; d < blockDim.x; d *= 2) {
    if (index + 1 - from > d) {
      indices[index] += indices[index-d];
    }
    __syncthreads();
  }
  result[index] = indices[index];
}

__global__
void map(int* result, int from) {
  int index = from + threadIdx.x;
  int to_map = result[from-1];
  result[index] += to_map;
  return;
}

__global__
void copy(int* result, int* indices, int* array, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < n) {
      if (array[index] % 2 == 1) {
        int idx = indices[index];
        result[idx] = array[index];
      }
  }
}

void radixSort(int* array, int n) {
    int threads = 1024;
    int blocks = (n + (threads-1)) / threads;
    
    int* indices;  // stores whether each element in array is odd or not (denoted 1 or 0)
    int* prefix;  // stores prefix sum of each element
    int* result;  // stores final result, sizeof prefix[n-1]
    int local_array_bytes = sizeof(int)*threads;
  
    cudaMallocManaged(&indices, sizeof(int) * n);
    cudaMallocManaged(&prefix, sizeof(int) * n);
    cudaMallocManaged(&result, sizeof(int) * n);

    for (int i = 1; i <= 1024; i <<= 2) {
        sort<<<blocks, threads>>>(indices, array, i, n);

        cudaDeviceSynchronize();
        printf("indices[999999]: %d\n", indices[999999]);

        prescan<<<blocks, threads, local_array_bytes>>>(prefix, indices, n); 

        // so far we've only calculated the positions of elements with 0 in the bit of interest
        // we need to use new index of the last element with a 0 in the bit of interest as an offset 
        // to calculate the positions of elements with 1 in the bit of interest
        // also I think we need to copy results -> input array at the end of each iteration for each bit of interest
  
        cudaDeviceSynchronize();
  
        for(int i = threads; i < n; i+=threads) {
        map<<<1, threads>>>(prefix, i); //map last value of previous group of 1024 onto next group of 1024
        cudaDeviceSynchronize();
        }
    }
  
    printf("prescan[999998]: %d, prescan[999999]: %d\n", prefix[999998], prefix[999999]);
  
    int maxOdds = prefix[n] + 1;
    printf("max number of odds: %d\n", prefix[n]);
  
    copy<<<blocks, threads>>>(result, prefix, array, n);
  
    cudaDeviceSynchronize();
  
     for(int i = maxOdds - 10; i < maxOdds; i++) {
       printf("index: %d result: %d\n", i, result[i]);
     }
  
  }


int main(int argc, char* argv[]){
    int n;
    int* array = fileToArray("inp.txt", &n);
    radixSort(array, n);
    cudaFree(array);
  }