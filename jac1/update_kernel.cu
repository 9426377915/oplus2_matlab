// 
// auto-generated by op2.m on 21-Apr-2011 18:29:23 
//

// user function                                                                  
                                                                                  
__device__                                                                        
#include "update.h"                                                               
                                                                                  
                                                                                  
// CUDA kernel function                                                           
                                                                                  
__global__ void op_cuda_update(                                                   
  float *arg0,                                                                    
  float *arg1,                                                                    
  float *arg2,                                                                    
  float *arg3,                                                                    
  float *arg4,                                                                    
  int   offset_s,                                                                 
  int   set_size ) {                                                              
                                                                                  
  float arg3_l[1];                                                                
  for (int d=0; d<1; d++) arg3_l[d]=ZERO_float;                                   
  float arg4_l[1];                                                                
  for (int d=0; d<1; d++) arg4_l[d]=arg4[d+blockIdx.x*1];                         
                                                                                  
  // process set elements                                                         
                                                                                  
  for (int n=threadIdx.x+blockIdx.x*blockDim.x;                                   
       n<set_size; n+=blockDim.x*gridDim.x) {                                     
                                                                                  
    // user-supplied kernel call                                                  
                                                                                  
    update( arg0+n,                                                               
            arg1+n,                                                               
            arg2+n,                                                               
            arg3_l,                                                               
            arg4_l );                                                             
  }                                                                               
                                                                                  
  // global reductions                                                            
                                                                                  
  for(int d=0; d<1; d++) op_reduction<OP_INC>(&arg3[d+blockIdx.x*1],arg3_l[d]);   
  for(int d=0; d<1; d++) op_reduction<OP_MAX>(&arg4[d+blockIdx.x*1],arg4_l[d]);   
}                                                                                 
                                                                                  
                                                                                  
// host stub function                                                             
                                                                                  
void op_par_loop_update(char const *name, op_set set,                             
  op_dat arg0, int idx0, op_map map0, int dim0, char const *typ0, op_access acc0, 
  op_dat arg1, int idx1, op_map map1, int dim1, char const *typ1, op_access acc1, 
  op_dat arg2, int idx2, op_map map2, int dim2, char const *typ2, op_access acc2, 
  float *arg3h,int idx3, op_map map3, int dim3, char const *typ3, op_access acc3, 
  float *arg4h,int idx4, op_map map4, int dim4, char const *typ4, op_access acc4){
                                                                                  
  op_dat_core arg3_dat = {NULL,0,0,(char *)arg3h,NULL,"float","gbl"};             
  op_dat      arg3     = &arg3_dat;                                               
  op_dat_core arg4_dat = {NULL,0,0,(char *)arg4h,NULL,"float","gbl"};             
  op_dat      arg4     = &arg4_dat;                                               
                                                                                  
  if (OP_diags>2) {                                                               
    printf(" kernel routine w/o indirection:  update \n");                        
  }                                                                               
                                                                                  
  // initialise timers                                                            
                                                                                  
  double cpu_t1, cpu_t2, wall_t1, wall_t2;                                        
  op_timers(&cpu_t1, &wall_t1);                                                   
                                                                                  
  // set CUDA execution parameters                                                
                                                                                  
  #ifdef OP_BLOCK_SIZE_1                                                          
    int nthread = OP_BLOCK_SIZE_1;                                                
  #else                                                                           
    // int nthread = OP_block_size;                                               
    int nthread = 128;                                                            
  #endif                                                                          
                                                                                  
  int nblocks = 200;                                                              
                                                                                  
  // transfer global reduction data to GPU                                        
                                                                                  
  int maxblocks = nblocks;                                                        
                                                                                  
  int reduct_bytes = 0;                                                           
  int reduct_size  = 0;                                                           
  reduct_bytes += ROUND_UP(maxblocks*1*sizeof(float));                            
  reduct_size   = MAX(reduct_size,sizeof(float));                                 
  reduct_bytes += ROUND_UP(maxblocks*1*sizeof(float));                            
  reduct_size   = MAX(reduct_size,sizeof(float));                                 
                                                                                  
  reallocReductArrays(reduct_bytes);                                              
                                                                                  
  reduct_bytes = 0;                                                               
  arg3->dat   = OP_reduct_h + reduct_bytes;                                       
  arg3->dat_d = OP_reduct_d + reduct_bytes;                                       
  for (int b=0; b<maxblocks; b++)                                                 
    for (int d=0; d<1; d++)                                                       
      ((float *)arg3->dat)[d+b*1] = ZERO_float;                                   
  reduct_bytes += ROUND_UP(maxblocks*1*sizeof(float));                            
  arg4->dat   = OP_reduct_h + reduct_bytes;                                       
  arg4->dat_d = OP_reduct_d + reduct_bytes;                                       
  for (int b=0; b<maxblocks; b++)                                                 
    for (int d=0; d<1; d++)                                                       
      ((float *)arg4->dat)[d+b*1] = arg4h[d];                                     
  reduct_bytes += ROUND_UP(maxblocks*1*sizeof(float));                            
                                                                                  
  mvReductArraysToDevice(reduct_bytes);                                           
                                                                                  
  // work out shared memory requirements per element                              
                                                                                  
  int nshared = 0;                                                                
                                                                                  
  // execute plan                                                                 
                                                                                  
  int offset_s = nshared*OP_WARPSIZE;                                             
                                                                                  
  nshared = MAX(nshared*nthread,reduct_size*nthread);                             
                                                                                  
  op_cuda_update<<<nblocks,nthread,nshared>>>( (float *) arg0->dat_d,             
                                               (float *) arg1->dat_d,             
                                               (float *) arg2->dat_d,             
                                               (float *) arg3->dat_d,             
                                               (float *) arg4->dat_d,             
                                               offset_s,                          
                                               set->size );                       
                                                                                  
  cutilSafeCall(cudaThreadSynchronize());                                         
  cutilCheckMsg("op_cuda_update execution failed\n");                             
                                                                                  
  // transfer global reduction data back to CPU                                   
                                                                                  
  mvReductArraysToHost(reduct_bytes);                                             
                                                                                  
  for (int b=0; b<maxblocks; b++)                                                 
    for (int d=0; d<1; d++)                                                       
      arg3h[d] = arg3h[d] + ((float *)arg3->dat)[d+b*1];                          
  for (int b=0; b<maxblocks; b++)                                                 
    for (int d=0; d<1; d++)                                                       
      arg4h[d] = MAX(arg4h[d],((float *)arg4->dat)[d+b*1]);                       
                                                                                  
  // update kernel record                                                         
                                                                                  
  op_timers(&cpu_t2, &wall_t2);                                                   
  op_timing_realloc(1);                                                           
  OP_kernels[1].name      = name;                                                 
  OP_kernels[1].count    += 1;                                                    
  OP_kernels[1].time     += wall_t2 - wall_t1;                                    
  OP_kernels[1].transfer += (float)set->size * arg0->size;                        
  OP_kernels[1].transfer += (float)set->size * arg1->size * 2.0f;                 
  OP_kernels[1].transfer += (float)set->size * arg2->size * 2.0f;                 
}                                                                                 
                                                                                  
