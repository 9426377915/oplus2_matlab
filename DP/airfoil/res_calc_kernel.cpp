// 
// auto-generated by op2.m on 11-Feb-2011 11:27:18 
//

// user function                                                                  
                                                                                  
#include "res_calc.h"                                                             
                                                                                  
                                                                                  
// x86 kernel function                                                            
                                                                                  
void op_x86_res_calc(                                                             
  int    blockIdx,                                                                
  double *ind_arg0, int *ind_arg0_maps,                                            
  double *ind_arg1, int *ind_arg1_maps,                                            
  double *ind_arg2, int *ind_arg2_maps,                                            
  double *ind_arg3, int *ind_arg3_maps,                                            
  short *arg0_maps,                                                               
  short *arg1_maps,                                                               
  short *arg2_maps,                                                               
  short *arg3_maps,                                                               
  short *arg4_maps,                                                               
  short *arg5_maps,                                                               
  short *arg6_maps,                                                               
  short *arg7_maps,                                                               
  int   *ind_arg_sizes,                                                           
  int   *ind_arg_offs,                                                            
  int    block_offset,                                                            
  int   *blkmap,                                                                  
  int   *offset,                                                                  
  int   *nelems,                                                                  
  int   *ncolors,                                                                 
  int   *colors) {                                                                
                                                                                  
  double arg6_l[4];                                                                
  double arg7_l[4];                                                                
                                                                                  
  int   *ind_arg0_map, ind_arg0_size;                                  
  int   *ind_arg1_map, ind_arg1_size;                                  
  int   *ind_arg2_map, ind_arg2_size;                                  
  int   *ind_arg3_map, ind_arg3_size;                                  
  double *ind_arg0_s;                                                   
  double *ind_arg1_s;                                                   
  double *ind_arg2_s;                                                   
  double *ind_arg3_s;                                                   
  int    nelems2, ncolor;                                              
  int    nelem, offset_b;                                              
                                                                                  
  char shared[64000];                                                  
                                                                                  
  if (0==0) {                                                                     
                                                                                  
    // get sizes and shift pointers and direct-mapped data                        
                                                                                  
    int blockId = blkmap[blockIdx + block_offset];                                
    nelem    = nelems[blockId];                                                   
    offset_b = offset[blockId];                                                   
                                                                                  
    nelems2  = nelem;                                                             
    ncolor   = ncolors[blockId];                                                  
                                                                                  
    ind_arg0_size = ind_arg_sizes[0+blockId*4];                                   
    ind_arg1_size = ind_arg_sizes[1+blockId*4];                                   
    ind_arg2_size = ind_arg_sizes[2+blockId*4];                                   
    ind_arg3_size = ind_arg_sizes[3+blockId*4];                                   
                                                                                  
    ind_arg0_map = ind_arg0_maps + ind_arg_offs[0+blockId*4];                     
    ind_arg1_map = ind_arg1_maps + ind_arg_offs[1+blockId*4];                     
    ind_arg2_map = ind_arg2_maps + ind_arg_offs[2+blockId*4];                     
    ind_arg3_map = ind_arg3_maps + ind_arg_offs[3+blockId*4];                     
                                                                                  
    // set shared memory pointers                                                 
                                                                                  
    int nbytes = 0;                                                               
    ind_arg0_s = (double *) &shared[nbytes];                                       
    nbytes    += ROUND_UP(ind_arg0_size*sizeof(double)*2);                         
    ind_arg1_s = (double *) &shared[nbytes];                                       
    nbytes    += ROUND_UP(ind_arg1_size*sizeof(double)*4);                         
    ind_arg2_s = (double *) &shared[nbytes];                                       
    nbytes    += ROUND_UP(ind_arg2_size*sizeof(double)*1);                         
    ind_arg3_s = (double *) &shared[nbytes];                                       
  }                                                                               
                                                                                  
  __syncthreads(); // make sure all of above completed                            
                                                                                  
  // copy indirect datasets into shared memory or zero increment                  
                                                                                  
  for (int n=0; n<ind_arg0_size; n++)                                             
    for (int d=0; d<2; d++)                                                       
      ind_arg0_s[d+n*2] = ind_arg0[d+ind_arg0_map[n]*2];                          
                                                                                  
  for (int n=0; n<ind_arg1_size; n++)                                             
    for (int d=0; d<4; d++)                                                       
      ind_arg1_s[d+n*4] = ind_arg1[d+ind_arg1_map[n]*4];                          
                                                                                  
  for (int n=0; n<ind_arg2_size; n++)                                             
    for (int d=0; d<1; d++)                                                       
      ind_arg2_s[d+n*1] = ind_arg2[d+ind_arg2_map[n]*1];                          
                                                                                  
  for (int n=0; n<ind_arg3_size; n++)                                             
    for (int d=0; d<4; d++)                                                       
      ind_arg3_s[d+n*4] = ZERO_double;                                             
                                                                                  
  __syncthreads();                                                                
                                                                                  
  // process set elements                                                         
                                                                                  
  for (int n=0; n<nelems2; n++) {                                                 
    int col2 = -1;                                                                
                                                                                  
    if (n<nelem) {                                                                
                                                                                  
      // initialise local variables                                               
                                                                                  
      for (int d=0; d<4; d++)                                                     
        arg6_l[d] = ZERO_double;                                                   
      for (int d=0; d<4; d++)                                                     
        arg7_l[d] = ZERO_double;                                                   
                                                                                  
      // user-supplied kernel call                                                
                                                                                  
      res_calc( ind_arg0_s+arg0_maps[n+offset_b]*2,                               
                ind_arg0_s+arg1_maps[n+offset_b]*2,                               
                ind_arg1_s+arg2_maps[n+offset_b]*4,                               
                ind_arg1_s+arg3_maps[n+offset_b]*4,                               
                ind_arg2_s+arg4_maps[n+offset_b]*1,                               
                ind_arg2_s+arg5_maps[n+offset_b]*1,                               
                arg6_l,                                                           
                arg7_l );                                                         
                                                                                  
      col2 = colors[n+offset_b];                                                  
    }                                                                             
                                                                                  
    // store local variables                                                      
                                                                                  
    int arg6_map = arg6_maps[n+offset_b];                                         
    int arg7_map = arg7_maps[n+offset_b];                                         
                                                                                  
    for (int col=0; col<ncolor; col++) {                                          
      if (col2==col) {                                                            
        for (int d=0; d<4; d++)                                                   
          ind_arg3_s[d+arg6_map*4] += arg6_l[d];                                  
        for (int d=0; d<4; d++)                                                   
          ind_arg3_s[d+arg7_map*4] += arg7_l[d];                                  
      }                                                                           
      __syncthreads();                                                            
    }                                                                             
                                                                                  
  }                                                                               
                                                                                  
  // apply pointered write/increment                                              
                                                                                  
  for (int n=0; n<ind_arg3_size; n++)                                             
    for (int d=0; d<4; d++)                                                       
      ind_arg3[d+ind_arg3_map[n]*4] += ind_arg3_s[d+n*4];                         
                                                                                  
}                                                                                 
                                                                                  
                                                                                  
// host stub function                                                             
                                                                                  
void op_par_loop_res_calc(char const *name, op_set set,                           
  op_dat arg0, int idx0, op_map map0, int dim0, char const *typ0, op_access acc0, 
  op_dat arg1, int idx1, op_map map1, int dim1, char const *typ1, op_access acc1, 
  op_dat arg2, int idx2, op_map map2, int dim2, char const *typ2, op_access acc2, 
  op_dat arg3, int idx3, op_map map3, int dim3, char const *typ3, op_access acc3, 
  op_dat arg4, int idx4, op_map map4, int dim4, char const *typ4, op_access acc4, 
  op_dat arg5, int idx5, op_map map5, int dim5, char const *typ5, op_access acc5, 
  op_dat arg6, int idx6, op_map map6, int dim6, char const *typ6, op_access acc6, 
  op_dat arg7, int idx7, op_map map7, int dim7, char const *typ7, op_access acc7){
                                                                                  
                                                                                  
  int         nargs = 8, ninds = 4;                                               
                                                                                  
  op_dat      args[8] = {arg0,arg1,arg2,arg3,arg4,arg5,arg6,arg7};                
  int         idxs[8] = {idx0,idx1,idx2,idx3,idx4,idx5,idx6,idx7};                
  op_map      maps[8] = {map0,map1,map2,map3,map4,map5,map6,map7};                
  int         dims[8] = {dim0,dim1,dim2,dim3,dim4,dim5,dim6,dim7};                
  char const *typs[8] = {typ0,typ1,typ2,typ3,typ4,typ5,typ6,typ7};                
  op_access   accs[8] = {acc0,acc1,acc2,acc3,acc4,acc5,acc6,acc7};                
  int         inds[8] = {0,0,1,1,2,2,3,3};                                        
                                                                                  
  if (OP_diags>2) {                                                               
    printf(" kernel routine with indirection: res_calc \n");                      
  }                                                                               
                                                                                  
  // get plan                                                                     
                                                                                  
  op_plan *Plan = plan(name,set,nargs,args,idxs,maps,dims,typs,accs,ninds,inds);  
                                                                                  
  // initialise timers                                                            
                                                                                  
  double cpu_t1, cpu_t2, wall_t1, wall_t2;                                        
  timers(&cpu_t1, &wall_t1);                                                      
                                                                                  
  // set number of threads                                                        
                                                                                  
#ifdef _OPENMP                                                                    
  int nthreads = omp_get_max_threads( );                                          
#else                                                                             
  int nthreads = 1;                                                               
#endif                                                                            
                                                                                  
  // execute plan                                                                 
                                                                                  
  int block_offset = 0;                                                           
                                                                                  
  for (int col=0; col<(*Plan).ncolors; col++) {                                   
    int nblocks = (*Plan).ncolblk[col];                                           
                                                                                  
#pragma omp parallel for                                                          
    for (int blockIdx=0; blockIdx<nblocks; blockIdx++)                            
     op_x86_res_calc( blockIdx,                                                   
       (double *)arg0.dat, (*Plan).ind_maps[0],                                    
       (double *)arg2.dat, (*Plan).ind_maps[1],                                    
       (double *)arg4.dat, (*Plan).ind_maps[2],                                    
       (double *)arg6.dat, (*Plan).ind_maps[3],                                    
       (*Plan).maps[0],                                                           
       (*Plan).maps[1],                                                           
       (*Plan).maps[2],                                                           
       (*Plan).maps[3],                                                           
       (*Plan).maps[4],                                                           
       (*Plan).maps[5],                                                           
       (*Plan).maps[6],                                                           
       (*Plan).maps[7],                                                           
       (*Plan).ind_sizes,                                                         
       (*Plan).ind_offs,                                                          
       block_offset,                                                              
       (*Plan).blkmap,                                                            
       (*Plan).offset,                                                            
       (*Plan).nelems,                                                            
       (*Plan).nthrcol,                                                           
       (*Plan).thrcol);                                                           
                                                                                  
    block_offset += nblocks;                                                      
  }                                                                               
                                                                                  
  // update kernel record                                                         
                                                                                  
  timers(&cpu_t2, &wall_t2);                                                      
  OP_kernels[2].name      = name;                                                 
  OP_kernels[2].count    += 1;                                                    
  OP_kernels[2].time     += wall_t2 - wall_t1;                                    
  OP_kernels[2].transfer  += (*Plan).transfer;                                    
  OP_kernels[2].transfer2 += (*Plan).transfer2;                                   
}                                                                                 
                                                                                  
