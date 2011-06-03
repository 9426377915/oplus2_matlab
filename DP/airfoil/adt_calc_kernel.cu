// 
// auto-generated by op2.m on 11-Feb-2011 11:27:18 
//

// user function                                                                  
                                                                                  
__device__                                                                        
#include "adt_calc.h"                                                             
                                                                                  
                                                                                  
// CUDA kernel function                                                           
                                                                                  
__global__ void op_cuda_adt_calc(                                                 
  double *ind_arg0, int *ind_arg0_maps,                                            
  short *arg0_maps,                                                               
  short *arg1_maps,                                                               
  short *arg2_maps,                                                               
  short *arg3_maps,                                                               
  double *arg4,                                                                    
  double *arg5,                                                                    
  int   *ind_arg_sizes,                                                           
  int   *ind_arg_offs,                                                            
  int    block_offset,                                                            
  int   *blkmap,                                                                  
  int   *offset,                                                                  
  int   *nelems,                                                                  
  int   *ncolors,                                                                 
  int   *colors) {                                                                
                                                                                  
                                                                                  
  __shared__ int   *ind_arg0_map, ind_arg0_size;                                  
  __shared__ double *ind_arg0_s;                                                   
  __shared__ int    nelem, offset_b;                                              
                                                                                  
  extern __shared__ char shared[];                                                
                                                                                  
  if (threadIdx.x==0) {                                                           
                                                                                  
    // get sizes and shift pointers and direct-mapped data                        
                                                                                  
    int blockId = blkmap[blockIdx.x + block_offset];                              
                                                                                  
    nelem    = nelems[blockId];                                                   
    offset_b = offset[blockId];                                                   
                                                                                  
    ind_arg0_size = ind_arg_sizes[0+blockId*1];                                   
                                                                                  
    ind_arg0_map = ind_arg0_maps + ind_arg_offs[0+blockId*1];                     
                                                                                  
    // set shared memory pointers                                                 
                                                                                  
    int nbytes = 0;                                                               
    ind_arg0_s = (double *) &shared[nbytes];                                       
  }                                                                               
                                                                                  
  __syncthreads(); // make sure all of above completed                            
                                                                                  
  // copy indirect datasets into shared memory or zero increment                  
                                                                                  
  for (int n=threadIdx.x; n<ind_arg0_size*2; n+=blockDim.x)                       
    ind_arg0_s[n] = ind_arg0[n%2+ind_arg0_map[n/2]*2];                            
                                                                                  
  __syncthreads();                                                                
                                                                                  
  // process set elements                                                         
                                                                                  
  for (int n=threadIdx.x; n<nelem; n+=blockDim.x) {                               
                                                                                  
      // user-supplied kernel call                                                
                                                                                  
      adt_calc( ind_arg0_s+arg0_maps[n+offset_b]*2,                               
                ind_arg0_s+arg1_maps[n+offset_b]*2,                               
                ind_arg0_s+arg2_maps[n+offset_b]*2,                               
                ind_arg0_s+arg3_maps[n+offset_b]*2,                               
                arg4+(n+offset_b)*4,                                              
                arg5+(n+offset_b)*1 );                                            
  }                                                                               
                                                                                  
}                                                                                 
                                                                                  
                                                                                  
// host stub function                                                             
                                                                                  
void op_par_loop_adt_calc(char const *name, op_set set,                           
  op_dat arg0, int idx0, op_map map0, int dim0, char const *typ0, op_access acc0, 
  op_dat arg1, int idx1, op_map map1, int dim1, char const *typ1, op_access acc1, 
  op_dat arg2, int idx2, op_map map2, int dim2, char const *typ2, op_access acc2, 
  op_dat arg3, int idx3, op_map map3, int dim3, char const *typ3, op_access acc3, 
  op_dat arg4, int idx4, op_map map4, int dim4, char const *typ4, op_access acc4, 
  op_dat arg5, int idx5, op_map map5, int dim5, char const *typ5, op_access acc5){
                                                                                  
                                                                                  
  int         nargs = 6, ninds = 1;                                               
                                                                                  
  op_dat      args[6] = {arg0,arg1,arg2,arg3,arg4,arg5};                          
  int         idxs[6] = {idx0,idx1,idx2,idx3,idx4,idx5};                          
  op_map      maps[6] = {map0,map1,map2,map3,map4,map5};                          
  int         dims[6] = {dim0,dim1,dim2,dim3,dim4,dim5};                          
  char const *typs[6] = {typ0,typ1,typ2,typ3,typ4,typ5};                          
  op_access   accs[6] = {acc0,acc1,acc2,acc3,acc4,acc5};                          
  int         inds[6] = {0,0,0,0,-1,-1};                                          
                                                                                  
  if (OP_diags>2) {                                                               
    printf(" kernel routine with indirection: adt_calc \n");                      
  }                                                                               
                                                                                  
  // get plan                                                                     
                                                                                  
  op_plan *Plan = plan(name,set,nargs,args,idxs,maps,dims,typs,accs,ninds,inds);  
                                                                                  
  // initialise timers                                                            
                                                                                  
  double cpu_t1, cpu_t2, wall_t1, wall_t2;                                        
  timers(&cpu_t1, &wall_t1);                                                      
                                                                                  
  // execute plan                                                                 
                                                                                  
  int block_offset = 0;                                                           
                                                                                  
  for (int col=0; col<(*Plan).ncolors; col++) {                                   
                                                                                  
    int nblocks = (*Plan).ncolblk[col];                                           
    int nthread = OP_block_size;                                                  
    int nshared = (*Plan).nshared;                                                
    op_cuda_adt_calc<<<nblocks,nthread,nshared>>>(                                
       (double *)arg0.dat_d, (*Plan).ind_maps[0],                                  
       (*Plan).maps[0],                                                           
       (*Plan).maps[1],                                                           
       (*Plan).maps[2],                                                           
       (*Plan).maps[3],                                                           
       (double *)arg4.dat_d,                                                       
       (double *)arg5.dat_d,                                                       
       (*Plan).ind_sizes,                                                         
       (*Plan).ind_offs,                                                          
       block_offset,                                                              
       (*Plan).blkmap,                                                            
       (*Plan).offset,                                                            
       (*Plan).nelems,                                                            
       (*Plan).nthrcol,                                                           
       (*Plan).thrcol);                                                           
                                                                                  
    cutilSafeCall(cudaThreadSynchronize());                                       
    cutilCheckMsg("op_cuda_adt_calc execution failed\n");                         
                                                                                  
    block_offset += nblocks;                                                      
  }                                                                               
                                                                                  
  // update kernel record                                                         
                                                                                  
  timers(&cpu_t2, &wall_t2);                                                      
  OP_kernels[1].name      = name;                                                 
  OP_kernels[1].count    += 1;                                                    
  OP_kernels[1].time     += wall_t2 - wall_t1;                                    
  OP_kernels[1].transfer  += (*Plan).transfer;                                    
  OP_kernels[1].transfer2 += (*Plan).transfer2;                                   
}                                                                                 
                                                                                  
