// 
// auto-generated by op2.m on 11-Feb-2011 10:27:59 
//

// user function                                                                  
                                                                                  
__device__                                                                        
#include "res.h"                                                                  
                                                                                  
                                                                                  
// CUDA kernel function                                                           
                                                                                  
__global__ void op_cuda_res(                                                      
  double *ind_arg0, int *ind_arg0_maps,                                            
  double *ind_arg1, int *ind_arg1_maps,                                            
  double *arg0,                                                                    
  short *arg1_maps,                                                               
  short *arg2_maps,                                                               
  const double *arg3,                                                              
  int   *ind_arg_sizes,                                                           
  int   *ind_arg_offs,                                                            
  int    block_offset,                                                            
  int   *blkmap,                                                                  
  int   *offset,                                                                  
  int   *nelems,                                                                  
  int   *ncolors,                                                                 
  int   *colors) {                                                                
                                                                                  
  double arg2_l[1];                                                                
                                                                                  
  __shared__ int   *ind_arg0_map, ind_arg0_size;                                  
  __shared__ int   *ind_arg1_map, ind_arg1_size;                                  
  __shared__ double *ind_arg0_s;                                                   
  __shared__ double *ind_arg1_s;                                                   
  __shared__ int    nelems2, ncolor;                                              
  __shared__ int    nelem, offset_b;                                              
                                                                                  
  extern __shared__ char shared[];                                                
                                                                                  
  if (threadIdx.x==0) {                                                           
                                                                                  
    // get sizes and shift pointers and direct-mapped data                        
                                                                                  
    int blockId = blkmap[blockIdx.x + block_offset];                              
                                                                                  
    nelem    = nelems[blockId];                                                   
    offset_b = offset[blockId];                                                   
                                                                                  
    nelems2  = blockDim.x*(1+(nelem-1)/blockDim.x);                               
    ncolor   = ncolors[blockId];                                                  
                                                                                  
    ind_arg0_size = ind_arg_sizes[0+blockId*2];                                   
    ind_arg1_size = ind_arg_sizes[1+blockId*2];                                   
                                                                                  
    ind_arg0_map = ind_arg0_maps + ind_arg_offs[0+blockId*2];                     
    ind_arg1_map = ind_arg1_maps + ind_arg_offs[1+blockId*2];                     
                                                                                  
    // set shared memory pointers                                                 
                                                                                  
    int nbytes = 0;                                                               
    ind_arg0_s = (double *) &shared[nbytes];                                       
    nbytes    += ROUND_UP(ind_arg0_size*sizeof(double)*1);                         
    ind_arg1_s = (double *) &shared[nbytes];                                       
  }                                                                               
                                                                                  
  __syncthreads(); // make sure all of above completed                            
                                                                                  
  // copy indirect datasets into shared memory or zero increment                  
                                                                                  
  for (int n=threadIdx.x; n<ind_arg0_size*1; n+=blockDim.x)                       
    ind_arg0_s[n] = ind_arg0[n%1+ind_arg0_map[n/1]*1];                            
                                                                                  
  for (int n=threadIdx.x; n<ind_arg1_size*1; n+=blockDim.x)                       
    ind_arg1_s[n] = ZERO_double;                                                   
                                                                                  
  __syncthreads();                                                                
                                                                                  
  // process set elements                                                         
                                                                                  
  for (int n=threadIdx.x; n<nelems2; n+=blockDim.x) {                             
    int col2 = -1;                                                                
                                                                                  
    if (n<nelem) {                                                                
                                                                                  
      // initialise local variables                                               
                                                                                  
      for (int d=0; d<1; d++)                                                     
        arg2_l[d] = ZERO_double;                                                   
                                                                                  
      // user-supplied kernel call                                                
                                                                                  
      res( arg0+(n+offset_b)*1,                                                   
           ind_arg0_s+arg1_maps[n+offset_b]*1,                                    
           arg2_l,                                                                
           arg3 );                                                                
                                                                                  
      col2 = colors[n+offset_b];                                                  
    }                                                                             
                                                                                  
    // store local variables                                                      
                                                                                  
    int arg2_map = arg2_maps[n+offset_b];                                         
                                                                                  
    for (int col=0; col<ncolor; col++) {                                          
      if (col2==col) {                                                            
        for (int d=0; d<1; d++)                                                   
          ind_arg1_s[d+arg2_map*1] += arg2_l[d];                                  
      }                                                                           
      __syncthreads();                                                            
    }                                                                             
                                                                                  
  }                                                                               
                                                                                  
  // apply pointered write/increment                                              
                                                                                  
  for (int n=threadIdx.x; n<ind_arg1_size*1; n+=blockDim.x)                       
    ind_arg1[n%1+ind_arg1_map[n/1]*1] += ind_arg1_s[n];                           
                                                                                  
}                                                                                 
                                                                                  
                                                                                  
// host stub function                                                             
                                                                                  
void op_par_loop_res(char const *name, op_set set,                                
  op_dat arg0, int idx0, op_map map0, int dim0, char const *typ0, op_access acc0, 
  op_dat arg1, int idx1, op_map map1, int dim1, char const *typ1, op_access acc1, 
  op_dat arg2, int idx2, op_map map2, int dim2, char const *typ2, op_access acc2, 
  double *arg3h,int idx3, op_map map3, int dim3, char const *typ3, op_access acc3){
                                                                                  
  op_dat arg3 = {{0,0,"null"},0,0,0,(char *)arg3h,NULL,"double","gbl"};            
                                                                                  
  int         nargs = 4, ninds = 2;                                               
                                                                                  
  op_dat      args[4] = {arg0,arg1,arg2,arg3};                                    
  int         idxs[4] = {idx0,idx1,idx2,idx3};                                    
  op_map      maps[4] = {map0,map1,map2,map3};                                    
  int         dims[4] = {dim0,dim1,dim2,dim3};                                    
  char const *typs[4] = {typ0,typ1,typ2,typ3};                                    
  op_access   accs[4] = {acc0,acc1,acc2,acc3};                                    
  int         inds[4] = {-1,0,1,-1};                                              
                                                                                  
  if (OP_diags>2) {                                                               
    printf(" kernel routine with indirection: res \n");                           
  }                                                                               
                                                                                  
  // get plan                                                                     
                                                                                  
  op_plan *Plan = plan(name,set,nargs,args,idxs,maps,dims,typs,accs,ninds,inds);  
                                                                                  
  // initialise timers                                                            
                                                                                  
  double cpu_t1, cpu_t2, wall_t1, wall_t2;                                        
  timers(&cpu_t1, &wall_t1);                                                      
                                                                                  
  // transfer constants to GPU                                                    
                                                                                  
  int consts_bytes = 0;                                                           
  consts_bytes += ROUND_UP(1*sizeof(double));                                      
                                                                                  
  reallocConstArrays(consts_bytes);                                               
                                                                                  
  consts_bytes = 0;                                                               
  arg3.dat   = OP_consts_h + consts_bytes;                                        
  arg3.dat_d = OP_consts_d + consts_bytes;                                        
  for (int d=0; d<1; d++) ((double *)arg3.dat)[d] = ((double *)arg3h)[d];           
  consts_bytes += ROUND_UP(1*sizeof(double));                                      
                                                                                  
  mvConstArraysToDevice(consts_bytes);                                            
                                                                                  
  // execute plan                                                                 
                                                                                  
  int block_offset = 0;                                                           
                                                                                  
  for (int col=0; col<(*Plan).ncolors; col++) {                                   
                                                                                  
    int nblocks = (*Plan).ncolblk[col];                                           
    int nthread = OP_block_size;                                                  
    int nshared = (*Plan).nshared;                                                
    op_cuda_res<<<nblocks,nthread,nshared>>>(                                     
       (double *)arg1.dat_d, (*Plan).ind_maps[0],                                  
       (double *)arg2.dat_d, (*Plan).ind_maps[1],                                  
       (double *)arg0.dat_d,                                                       
       (*Plan).maps[1],                                                           
       (*Plan).maps[2],                                                           
       (double *)arg3.dat_d,                                                       
       (*Plan).ind_sizes,                                                         
       (*Plan).ind_offs,                                                          
       block_offset,                                                              
       (*Plan).blkmap,                                                            
       (*Plan).offset,                                                            
       (*Plan).nelems,                                                            
       (*Plan).nthrcol,                                                           
       (*Plan).thrcol);                                                           
                                                                                  
    cutilSafeCall(cudaThreadSynchronize());                                       
    cutilCheckMsg("op_cuda_res execution failed\n");                              
                                                                                  
    block_offset += nblocks;                                                      
  }                                                                               
                                                                                  
  // update kernel record                                                         
                                                                                  
  timers(&cpu_t2, &wall_t2);                                                      
  OP_kernels[0].name      = name;                                                 
  OP_kernels[0].count    += 1;                                                    
  OP_kernels[0].time     += wall_t2 - wall_t1;                                    
  OP_kernels[0].transfer  += (*Plan).transfer;                                    
  OP_kernels[0].transfer2 += (*Plan).transfer2;                                   
}                                                                                 
                                                                                  