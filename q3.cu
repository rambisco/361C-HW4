#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#define NUM_THREADS 512
#define NUM_BLOCKS 1
#define ZERO_BANK_CONFLICTS 1
#define NUM_BANKS 16
#define LOG_NUM_BANKS 4
#ifdef ZERO_BANK_CONFLICTS
#define CONFLICT_FREE_OFFSET(n) \
 ((n) >> NUM_BANKS + (n) >> (2 * LOG_NUM_BANKS))
#else
#define CONFLICT_FREE_OFFSET(n) ((n) >> LOG_NUM_BANKS)
#endif

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

// __global__
// void countodds(int* array, int* result, int n) {
  
//   int index = blockIdx.x * blockDim.x + threadIdx.x;
//   int stride = blockDim.x * gridDim.x;
//   for (int i = index; i < n; i += stride) {
//     atomicAdd(result, 1);
//   }
// }

// __global__
// void odds(int* array, int* result, int n){
//   int index = blockIdx.x * blockDim.x + threadIdx.x;
//   int stride = blockDim.x * gridDim.x;
//   for (int i = index; i < n; i += stride) {
//     atomicAdd(result, 1);
//   }


// }

// __global__ void prescan(int* result, int* array, int n) {
  //n = NUM_THREADS; //we cant do more than this yet
  // extern __shared__ int counts[];
  // int thid = blockIdx.x * blockDim.x + threadIdx.x;
  //int thid = threadIdx.x;
  // int offset = 1;

  // int ai = thid;
  // int bi = thid + (n/2);
  // int bankOffsetA = CONFLICT_FREE_OFFSET(ai);
  // int bankOffsetB = CONFLICT_FREE_OFFSET(ai);

  // counts[ai + bankOffsetA] = ((array[ai] % 2) == 0) ? 0 : 1;
  // counts[bi + bankOffsetB] = ((array[bi] % 2) == 0) ? 0 : 1;

//   for (int d = n>>1; d > 0; d >>= 1) {
//     __syncthreads();
//     if (thid < d) {
//       int ai = offset*(2*thid+1)-1;
//       int bi = offset*(2*thid+2)-1;
//       ai += CONFLICT_FREE_OFFSET(ai);
//       bi += CONFLICT_FREE_OFFSET(bi); 
//       counts[bi] += counts[ai]; 
//     }
//     offset *= 2;
//   }
  
//   if (thid == 0) {
//     counts[n - 1 + CONFLICT_FREE_OFFSET(n - 1)] = 0;
//   }

//   for (int d = 1; d < n; d *= 2) {
//     offset >>= 1;
//     __syncthreads();
//     if (thid < d) {
//       int ai = offset*(2*thid+1)-1;
//       int bi = offset*(2*thid+2)-1;
//       ai += CONFLICT_FREE_OFFSET(ai);
//       bi += CONFLICT_FREE_OFFSET(bi); 
//       int t = counts[ai];
//       counts[ai] = counts[bi];
//       counts[bi] += t;
//     }
//   }
//   __syncthreads();
//   result[ai] = counts[ai + bankOffsetA];
//   result[bi] = counts[bi + bankOffsetB]; 
// }
__global__ 
void odds(int* result, int* array, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < n) {
    result[index] = array[index] % 2;
  } 
}

__global__ 
void prescan(int* result, int* odds, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  for (int d = 1; d < n; d *= 2) {
    if (index+1 > d && index < n) {
      odds[index] += odds[index-d];
    }
    __syncthreads();
  }
  result[index] = odds[index];
}

__global__
void copy(int* result, int* odds, int* array, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  // int stride = blockDim.x * gridDim.x;
  // for (int i = index; i < n; i += stride) {
  //   if (array[i] % 2 == 1) {
  //     int idx = odds[i];
  //     result[idx] = array[i];
  //   }
  // }
  if (index < n) {
      if (array[index] % 2 == 1) {
        int idx = odds[index];
        result[idx] = array[index];
      }
  }
}
 

//   printf("max number of odds: %d\n", odds[n-1]);

void copyOdds(int* array, int n) {
  int threads = 1024;
  int blocks = (n + (threads-1)) / threads;
  

  int* ones;  // stores whether each element in array is odd or not (denoted 1 or 0)
  int* prefix;  // stores prefix sum of each element
  int* result;  // stores final result, sizeof prefix[n-1]

  cudaMallocManaged(&ones, sizeof(int) * n);
  cudaMallocManaged(&prefix, sizeof(int) * n);

  odds<<<blocks, threads>>>(ones, array, n);

  cudaDeviceSynchronize();

  prescan<<<blocks, threads>>>(prefix, ones, n);

  cudaDeviceSynchronize();

  int maxOdds = prefix[n-1];
  printf("max number of odds: %d\n", prefix[n-1]);

  for(int i = 0; i < threads; i++) {
    printf("is index %d odds? %d\n", i, prefix[i]);
  }

  cudaMallocManaged(&result, sizeof(int) * maxOdds);

  copy<<<blocks, threads>>>(result, prefix, array, n);

  cudaDeviceSynchronize();

  // for(int i = 1; i < threads; i++) {
  //   printf("index: %d result: %d\n", i, result[i]);
  // }

}

int main(int argc, char* argv[]){
  int n;
  int* array = fileToArray("inp.txt", &n);
  
  // for (int i = 0; i < n; i++) {
  //   printf("Is %d odds? %d\n", array[i], ((array[i] % 2) == 0) ? 0 : 1);
  // }
  copyOdds(array, n);
  //int min = computeMin(array, n);
  //printf("min: %d\n", min);
  cudaFree(array);
}