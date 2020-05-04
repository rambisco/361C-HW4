#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#define NUM_THREADS 512
#define NUM_BLOCKS 1
#define ZERO_BANK_CONFLICTS 1
#define OUTPUT_FILE_NAME "q3.txt"
#define NUM_BANKS 16
#define LOG_NUM_BANKS 4
#ifdef ZERO_BANK_CONFLICTS
#define CONFLICT_FREE_OFFSET(n) \
 ((n) >> NUM_BANKS + (n) >> (2 * LOG_NUM_BANKS))
#else
#define CONFLICT_FREE_OFFSET(n) ((n) >> LOG_NUM_BANKS)
#endif

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
  //char* str = (char*) malloc(sizeof(char)*2048);
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
void odds(int* result, int* array, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < n) {
    result[index] = array[index] % 2;
  } 
}

__global__ 
void prescan(int* result, int* odds, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  extern __shared__ int local_scan[];
  int from = blockIdx.x * blockDim.x;
  int to = blockIdx.x * blockDim.x + blockDim.x; 
   
  for (int d = 1; d < blockDim.x; d *= 2) {
    if (index + 1 - from > d) {
      odds[index] += odds[index-d];
    }
    __syncthreads();
  }
  result[index] = odds[index];
}

__global__
void map(int* result, int from) {
  int index = from + threadIdx.x;
  int to_map = result[from-1];
  result[index] += to_map;
  return;
}

__global__
void copy(int* result, int* odds, int* array, int n) {
  int index = blockIdx.x * blockDim.x + threadIdx.x;
  if (index < n) {
      if (array[index] % 2 == 1) {
        int idx = odds[index];
        result[idx] = array[index];
      }
  }
}

void copyOdds(int* array, int n) {
  int threads = 1024;
  int blocks = (n + (threads-1)) / threads;
  

  int* ones;  // stores whether each element in array is odd or not (denoted 1 or 0)
  int* prefix;  // stores prefix sum of each element
  int* result;  // stores final result, sizeof prefix[n-1]
  int local_array_bytes = sizeof(int)*threads;

  cudaMallocManaged(&ones, sizeof(int) * n);
  cudaMallocManaged(&prefix, sizeof(int) * n);

  odds<<<blocks, threads>>>(ones, array, n);
  printf("ones[999999]: %d\n", ones[999999]);

  cudaDeviceSynchronize();

  prescan<<<blocks, threads, local_array_bytes>>>(prefix, ones, n); 


  cudaDeviceSynchronize();

  for(int i = threads; i < n; i+=threads) {
    map<<<1, threads>>>(prefix, i); //map last value of previous group of 1024 onto next group of 1024
    cudaDeviceSynchronize();
  }

  printf("prescan[999998]: %d, prescan[999999]: %d\n", prefix[999998], prefix[999999]);

  int maxOdds = prefix[n] + 1;
  printf("max number of odds: %d\n", prefix[n]);

  cudaMallocManaged(&result, sizeof(int) * maxOdds);

  copy<<<blocks, threads>>>(result, prefix, array, n);

  cudaDeviceSynchronize();

   for(int i = maxOdds - 10; i < maxOdds; i++) {
     printf("index: %d result: %d\n", i, result[i]);
   }

  // FILE *output = fopen(OUTPUT_FILE_NAME, "w");
  // if(output == NULL) printf("failed to open file %s\n", OUTPUT_FILE_NAME);
  // fprintf(output, "%d", result[0]);
  // for(int i = 0; i < maxOdds ; i++) {
  //   fprintf(output, ",%d", result[i]);
  // }
  // fclose(output);
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