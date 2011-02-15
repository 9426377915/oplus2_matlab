// 
// auto-generated by op2.m on 31-Oct-2010 14:33:26 
//

// user function                                                                  
                                                                                  
__device__                                                                        
#include "save_soln.h"                                                            
                                                                                  
                                                                                  
// CUDA kernel function                                                           
                                                                                  
__global__ void op_cuda_save_soln(                                                
  float *arg0,                                                                    
  float *arg1,                                                                    
  int   set_size ) {                                                              
                                                                                  
                                                                                  
  // process set elements                                                         
                                                                                  
  for (int n=threadIdx.x+blockIdx.x*blockDim.x;                                   
       n<set_size; n+=blockDim.x*gridDim.x) {                                     
                                                                                  
      // user-supplied kernel call                                                
                                                                                  
      save_soln( arg0+n*4,                                                        
                 arg1+n*4 );                                                      
  }                                                                               
}                                                                                 
                                                                                  
                                                                                  
// host stub function                                                             
                                                                                  
void op_par_loop_save_soln(char const *name, op_set set,                          
  op_dat arg0, int idx0, op_ptr ptr0, int dim0, char const *typ0, op_access acc0, 
  op_dat arg1, int idx1, op_ptr ptr1, int dim1, char const *typ1, op_access acc1){
                                                                                  
                                                                                  
  if (OP_diags>2) {                                                               
    printf(" kernel routine w/o indirection:  save_soln \n");                     
  }                                                                               
                                                                                  
  // initialise timers                                                            
                                                                                  
  double cpu_t1, cpu_t2, wall_t1, wall_t2;                                        
  timers(&cpu_t1, &wall_t1);                                                      
                                                                                  
  // execute plan                                                                 
                                                                                  
  int nblocks = 100;                                                              
  int nthread = OP_block_size;                                                    
  op_cuda_save_soln<<<nblocks,nthread>>>( (float *) arg0.dat_d,                   
                                          (float *) arg1.dat_d,                   
                                          set.size );                             
                                                                                  
  cutilSafeCall(cudaThreadSynchronize());                                         
  cutilCheckMsg("op_cuda_save_soln execution failed\n");                          
                                                                                  
  // update kernel record                                                         
                                                                                  
  timers(&cpu_t2, &wall_t2);                                                      
  OP_kernels[0].name      = name;                                                 
  OP_kernels[0].count    += 1;                                                    
  OP_kernels[0].time     += wall_t2 - wall_t1;                                    
  OP_kernels[0].transfer += (float)set.size * arg0.size;                          
  OP_kernels[0].transfer += (float)set.size * arg1.size * 2.0f;                   
}                                                                                 
                                                                                  
