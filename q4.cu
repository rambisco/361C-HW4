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
void maskArray(int* result2, int* result, int* array, int mask, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < n) {

    // this is the relative index
    result[index] = array[index] & mask;
    result2[index] = !(array[index] & mask);
  } 
}

__global__ 
void prescan(int* indices, int n) {
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
}

__global__
void map(int* result, int from) {
  int index = from + threadIdx.x;
  int to_map = result[from-1];
  result[index] += to_map;
  return;
}

__global__
void copy(int* result, int* array, int* ones, int* zeroes, int n, int pivot, int mask) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < n) {
      if (array[index] & mask) {
        int idx = ones[index];
        result[idx + pivot] = array[index];
      }
      else {
        int idx = zeroes[index];
        result[idx] = array[index];
      }
  }
}

void radixSort(int* array, int n) {
    int threads = 1024;
    int blocks = (n + (threads-1)) / threads;
    
    // stores whether each element in array is odd or not (denoted 1 or 0)
    int* ones;
    int* zeroes;
    int* result_copy;  // stores prefix sum of each element
    int* result;  // stores final result, sizeof prefix[n-1]
    int local_array_bytes = sizeof(int)*threads;

    cudaMallocManaged(&result_copy, sizeof(int) * n);
    cudaMallocManaged(&result, sizeof(int) * n);
    cudaMallocManaged(&ones, sizeof(int) * n);
    cudaMallocManaged(&zeroes, sizeof(int) * n);

    for (int i = 1; i <= 1024; i <<= 1) {
        maskArray<<<blocks, threads>>>(zeroes, ones, array, i, n);

        cudaDeviceSynchronize();

        prescan<<<blocks, threads, local_array_bytes>>>(zeroes, n); 

        for(int i = threads; i < n; i+=threads) {
        map<<<1, threads>>>(zeroes, i); //map last value of previous group of 1024 onto next group of 1024
        cudaDeviceSynchronize();
        }

        prescan<<<blocks, threads, local_array_bytes>>>(ones, n); 

        for(int i = threads; i < n; i+=threads) {
        map<<<1, threads>>>(ones, i); //map last value of previous group of 1024 onto next group of 1024
        cudaDeviceSynchronize();
        }

        int pivot = zeroes[n-1];

        // so far we've only calculated the positions of elements with 0 in the bit of interest
        // we need to use new index of the last element with a 0 in the bit of interest as an offset 
        // to calculate the positions of elements with 1 in the bit of interest
        // also I think we need to copy results -> input array at the end of each iteration for each bit of interest
  
        cudaDeviceSynchronize();
        copy<<<blocks, threads>>>(result, array, ones, zeroes, n, pivot, mask);
        for(int i = 0; i < 10; i++) {
          printf("result[%d]: %d\n", i, result[i]);
        }
    }
  
  }


int main(int argc, char* argv[]){
    int n;
    int* array = fileToArray("inp.txt", &n);
    radixSort(array, n);
    cudaFree(array);
  }