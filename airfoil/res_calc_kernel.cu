// 
// auto-generated by op2.m on 29-Oct-2010 14:49:58 
//

// user function                                                                           
                                                                                           
__device__                                                                                 
#include "res_calc.h"                                                                      
                                                                                           
                                                                                           
// CUDA kernel function                                                                    
                                                                                           
__global__ void op_cuda_res_calc(                                                          
  float *ind_arg0, int *ind_arg0_ptrs, int *ind_arg0_sizes, int *ind_arg0_offset,          
  float *ind_arg1, int *ind_arg1_ptrs, int *ind_arg1_sizes, int *ind_arg1_offset,          
  float *ind_arg2, int *ind_arg2_ptrs, int *ind_arg2_sizes, int *ind_arg2_offset,          
  float *ind_arg3, int *ind_arg3_ptrs, int *ind_arg3_sizes, int *ind_arg3_offset,          
  int   *arg0_ptrs,                                                                        
  int   *arg1_ptrs,                                                                        
  int   *arg2_ptrs,                                                                        
  int   *arg3_ptrs,                                                                        
  int   *arg4_ptrs,                                                                        
  int   *arg5_ptrs,                                                                        
  int   *arg6_ptrs,                                                                        
  int   *arg7_ptrs,                                                                        
  int *arg8_d,                                                                             
  int    block_offset,                                                                     
  int   *blkmap,                                                                           
  int   *offset,                                                                           
  int   *nelems,                                                                           
  int   *ncolors,                                                                          
  int   *colors) {                                                                         
                                                                                           
  float arg6_l[4];                                                                         
  float arg7_l[4];                                                                         
                                                                                           
  __shared__ int   *ind_arg0_ptr, ind_arg0_size;                                           
  __shared__ int   *ind_arg1_ptr, ind_arg1_size;                                           
  __shared__ int   *ind_arg2_ptr, ind_arg2_size;                                           
  __shared__ int   *ind_arg3_ptr, ind_arg3_size;                                           
  __shared__ float *ind_arg0_s;                                                            
  __shared__ float *ind_arg1_s;                                                            
  __shared__ float *ind_arg2_s;                                                            
  __shared__ float *ind_arg3_s;                                                            
  __shared__ int   *arg0_ptr;                                                              
  __shared__ int   *arg1_ptr;                                                              
  __shared__ int   *arg2_ptr;                                                              
  __shared__ int   *arg3_ptr;                                                              
  __shared__ int   *arg4_ptr;                                                              
  __shared__ int   *arg5_ptr;                                                              
  __shared__ int   *arg6_ptr;                                                              
  __shared__ int   *arg7_ptr;                                                              
  __shared__ int *arg8;                                                                    
  __shared__ int    nelems2, ncolor, *color;                                               
  __shared__ int    blockId, nelem;                                                        
                                                                                           
  extern __shared__ char shared[];                                                         
                                                                                           
  if (threadIdx.x==0) {                                                                    
                                                                                           
    // get sizes and shift pointers and direct-mapped data                                 
                                                                                           
    blockId = blkmap[blockIdx.x + block_offset];                                           
    nelem   = nelems[blockId];                                                             
                                                                                           
    nelems2 = blockDim.x*(1+(nelem-1)/blockDim.x);                                         
    ncolor  = ncolors[blockId];                                                            
    color   = colors + offset[blockId];                                                    
                                                                                           
    ind_arg0_size = ind_arg0_sizes[blockId];                                               
    ind_arg1_size = ind_arg1_sizes[blockId];                                               
    ind_arg2_size = ind_arg2_sizes[blockId];                                               
    ind_arg3_size = ind_arg3_sizes[blockId];                                               
                                                                                           
    ind_arg0_ptr = ind_arg0_ptrs + ind_arg0_offset[blockId];                               
    ind_arg1_ptr = ind_arg1_ptrs + ind_arg1_offset[blockId];                               
    ind_arg2_ptr = ind_arg2_ptrs + ind_arg2_offset[blockId];                               
    ind_arg3_ptr = ind_arg3_ptrs + ind_arg3_offset[blockId];                               
                                                                                           
    arg0_ptr     = arg0_ptrs + offset[blockId];                                            
    arg1_ptr     = arg1_ptrs + offset[blockId];                                            
    arg2_ptr     = arg2_ptrs + offset[blockId];                                            
    arg3_ptr     = arg3_ptrs + offset[blockId];                                            
    arg4_ptr     = arg4_ptrs + offset[blockId];                                            
    arg5_ptr     = arg5_ptrs + offset[blockId];                                            
    arg6_ptr     = arg6_ptrs + offset[blockId];                                            
    arg7_ptr     = arg7_ptrs + offset[blockId];                                            
    arg8         = arg8_d    + offset[blockId]*1;                                          
                                                                                           
    // set shared memory pointers                                                          
                                                                                           
    int nbytes = 0;                                                                        
    ind_arg0_s = (float *) &shared[nbytes];                                                
    nbytes    += ROUND_UP(ind_arg0_size*sizeof(float)*2);                                  
    ind_arg1_s = (float *) &shared[nbytes];                                                
    nbytes    += ROUND_UP(ind_arg1_size*sizeof(float)*4);                                  
    ind_arg2_s = (float *) &shared[nbytes];                                                
    nbytes    += ROUND_UP(ind_arg2_size*sizeof(float)*1);                                  
    ind_arg3_s = (float *) &shared[nbytes];                                                
  }                                                                                        
                                                                                           
  __syncthreads(); // make sure all of above completed                                     
                                                                                           
  // copy indirect datasets into shared memory or zero increment                           
                                                                                           
  for (int n=threadIdx.x; n<ind_arg0_size; n+=blockDim.x)                                  
    for (int d=0; d<2; d++)                                                                
      ind_arg0_s[d+n*2] = ind_arg0[d+ind_arg0_ptr[n]*2];                                   
                                                                                           
  for (int n=threadIdx.x; n<ind_arg1_size; n+=blockDim.x)                                  
    for (int d=0; d<4; d++)                                                                
      ind_arg1_s[d+n*4] = ind_arg1[d+ind_arg1_ptr[n]*4];                                   
                                                                                           
  for (int n=threadIdx.x; n<ind_arg2_size; n+=blockDim.x)                                  
    for (int d=0; d<1; d++)                                                                
      ind_arg2_s[d+n*1] = ind_arg2[d+ind_arg2_ptr[n]*1];                                   
                                                                                           
  for (int n=threadIdx.x; n<ind_arg3_size; n+=blockDim.x)                                  
    for (int d=0; d<4; d++)                                                                
      ind_arg3_s[d+n*4] = ZERO_float;                                                      
                                                                                           
  __syncthreads();                                                                         
                                                                                           
  // process set elements                                                                  
                                                                                           
  for (int n=threadIdx.x; n<nelems2; n+=blockDim.x) {                                      
    int col2 = -1;                                                                         
                                                                                           
    if (n<nelem) {                                                                         
                                                                                           
      // initialise local variables                                                        
                                                                                           
      for (int d=0; d<4; d++)                                                              
        arg6_l[d] = ZERO_float;                                                            
      for (int d=0; d<4; d++)                                                              
        arg7_l[d] = ZERO_float;                                                            
                                                                                           
      // user-supplied kernel call                                                         
                                                                                           
      res_calc( ind_arg0_s+arg0_ptr[n]*2,                                                  
                ind_arg0_s+arg1_ptr[n]*2,                                                  
                ind_arg1_s+arg2_ptr[n]*4,                                                  
                ind_arg1_s+arg3_ptr[n]*4,                                                  
                ind_arg2_s+arg4_ptr[n]*1,                                                  
                ind_arg2_s+arg5_ptr[n]*1,                                                  
                arg6_l,                                                                    
                arg7_l,                                                                    
                arg8+n*1 );                                                                
                                                                                           
      col2 = color[n];                                                                     
    }                                                                                      
                                                                                           
    // store local variables                                                               
                                                                                           
    for (int col=0; col<ncolor; col++) {                                                   
      if (col2==col) {                                                                     
        for (int d=0; d<4; d++)                                                            
          ind_arg3_s[d+arg6_ptr[n]*4] += arg6_l[d];                                        
        for (int d=0; d<4; d++)                                                            
          ind_arg3_s[d+arg7_ptr[n]*4] += arg7_l[d];                                        
      }                                                                                    
      __syncthreads();                                                                     
    }                                                                                      
                                                                                           
  }                                                                                        
                                                                                           
  // apply pointered write/increment                                                       
                                                                                           
  for (int n=threadIdx.x; n<ind_arg3_size; n+=blockDim.x)                                  
    for (int d=0; d<4; d++)                                                                
      ind_arg3[d+ind_arg3_ptr[n]*4] += ind_arg3_s[d+n*4];                                  
                                                                                           
}                                                                                          
                                                                                           
                                                                                           
// host stub function                                                                      
                                                                                           
void op_par_loop_res_calc(char const *name, op_set set,                                    
  op_dat arg0, int idx0, op_ptr ptr0, int dim0, char const *typ0, op_access acc0,          
  op_dat arg1, int idx1, op_ptr ptr1, int dim1, char const *typ1, op_access acc1,          
  op_dat arg2, int idx2, op_ptr ptr2, int dim2, char const *typ2, op_access acc2,          
  op_dat arg3, int idx3, op_ptr ptr3, int dim3, char const *typ3, op_access acc3,          
  op_dat arg4, int idx4, op_ptr ptr4, int dim4, char const *typ4, op_access acc4,          
  op_dat arg5, int idx5, op_ptr ptr5, int dim5, char const *typ5, op_access acc5,          
  op_dat arg6, int idx6, op_ptr ptr6, int dim6, char const *typ6, op_access acc6,          
  op_dat arg7, int idx7, op_ptr ptr7, int dim7, char const *typ7, op_access acc7,          
  op_dat arg8, int idx8, op_ptr ptr8, int dim8, char const *typ8, op_access acc8){         
                                                                                           
                                                                                           
  int         nargs = 9, ninds = 4;                                                        
                                                                                           
  op_dat      args[9] = {arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8};                    
  int         idxs[9] = {idx0,idx1,idx2,idx3,idx4,idx5,idx6,idx7,idx8};                    
  op_ptr      ptrs[9] = {ptr0,ptr1,ptr2,ptr3,ptr4,ptr5,ptr6,ptr7,ptr8};                    
  int         dims[9] = {dim0,dim1,dim2,dim3,dim4,dim5,dim6,dim7,dim8};                    
  char const *typs[9] = {typ0,typ1,typ2,typ3,typ4,typ5,typ6,typ7,typ8};                    
  op_access   accs[9] = {acc0,acc1,acc2,acc3,acc4,acc5,acc6,acc7,acc8};                    
  int         inds[9] = {0,0,1,1,2,2,3,3,-1};                                              
                                                                                           
  if (OP_diags>2) {                                                                        
    printf(" kernel routine with indirection: res_calc \n");                               
  }                                                                                        
                                                                                           
  // initialise timers                                                                     
                                                                                           
  double cpu_t1, cpu_t2, wall_t1, wall_t2;                                                 
  timers(&cpu_t1, &wall_t1);                                                               
                                                                                           
  // get plan                                                                              
                                                                                           
  op_plan *Plan = plan(name,set,nargs,args,idxs,ptrs,dims,typs,accs,ninds,inds);           
                                                                                           
  // execute plan                                                                          
                                                                                           
  int block_offset = 0;                                                                    
                                                                                           
  for (int col=0; col<(*Plan).ncolors; col++) {                                            
                                                                                           
    int nblocks = (*Plan).ncolblk[col];                                                    
    int nthread = OP_block_size;                                                           
    int nshared = (*Plan).nshared;                                                         
    printf(" nblocks, nthread, nshared = %d %d %d \n", nblocks, nthread, nshared);
    op_cuda_res_calc<<<nblocks,nthread,nshared>>>(                                         
       (float *)arg0.dat_d, (*Plan).ind_ptrs[0], (*Plan).ind_sizes[0], (*Plan).ind_offs[0],
       (float *)arg2.dat_d, (*Plan).ind_ptrs[1], (*Plan).ind_sizes[1], (*Plan).ind_offs[1],
       (float *)arg4.dat_d, (*Plan).ind_ptrs[2], (*Plan).ind_sizes[2], (*Plan).ind_offs[2],
       (float *)arg6.dat_d, (*Plan).ind_ptrs[3], (*Plan).ind_sizes[3], (*Plan).ind_offs[3],
       (*Plan).ptrs[0],                                                                    
       (*Plan).ptrs[1],                                                                    
       (*Plan).ptrs[2],                                                                    
       (*Plan).ptrs[3],                                                                    
       (*Plan).ptrs[4],                                                                    
       (*Plan).ptrs[5],                                                                    
       (*Plan).ptrs[6],                                                                    
       (*Plan).ptrs[7],                                                                    
       (int *)arg8.dat_d,                                                                  
       block_offset,                                                                       
       (*Plan).blkmap,                                                                     
       (*Plan).offset,                                                                     
       (*Plan).nelems,                                                                     
       (*Plan).nthrcol,                                                                    
       (*Plan).thrcol);                                                                    
                                                                                           
    cutilSafeCall(cudaThreadSynchronize());                                                
    cutilCheckMsg("op_cuda_res_calc execution failed\n");                                  
                                                                                           
    block_offset += nblocks;                                                               
  }                                                                                        
                                                                                           
  // update kernel record                                                                  
                                                                                           
  timers(&cpu_t2, &wall_t2);                                                               
  OP_kernels[2].name   = name;                                                             
  OP_kernels[2].count += 1;                                                                
  OP_kernels[2].time  += wall_t2 - wall_t1;                                                
}                                                                                          
                                                                                           
