/*
  Open source copyright declaration based on BSD open source template:
  http://www.opensource.org/licenses/bsd-license.php

* Copyright (c) 2009, Mike Giles
* All rights reserved.
*
* Redistribution and use in source and binary forms, with or without
* modification, are permitted provided that the following conditions are met:
*     * Redistributions of source code must retain the above copyright
*       notice, this list of conditions and the following disclaimer.
*     * Redistributions in binary form must reproduce the above copyright
*       notice, this list of conditions and the following disclaimer in the
*       documentation and/or other materials provided with the distribution.
*     * The name of Mike Giles may not be used to endorse or promote products
*       derived from this software without specific prior written permission.
*
* THIS SOFTWARE IS PROVIDED BY Mike Giles ''AS IS'' AND ANY
* EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
* WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
* DISCLAIMED. IN NO EVENT SHALL Mike Giles BE LIABLE FOR ANY
* DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
* (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
* LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
* ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
* SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

//
// header files
//

#include <stdlib.h>                                                         
#include <stdio.h>                                                          
#include <string.h>                                                         
#include <math.h>                                                           

#ifndef OP_x86
#include <cutil_inline.h>
#include <math_constants.h>
#endif

#include "op_datatypes.h"
#include "timers.h"

//
// global variables
//

#define OP_WARPSIZE 32

int OP_set_index =0, OP_set_max =0,
    OP_map_index =0, OP_map_max =0,
    OP_dat_index =0, OP_dat_max =0,
    OP_plan_index=0, OP_plan_max=0,
    OP_diags     =0,
    OP_part_size =0,
    OP_block_size=512,
    OP_cache_line_size=128;

op_set  **OP_set_list;
op_map  **OP_map_list;
op_dat  **OP_dat_list;
op_plan  *OP_plans;
op_kernel OP_kernels[OP_KERNELS_MAX];

// arrays for global constants and reductions

int   OP_consts_bytes=0,    OP_reduct_bytes=0;
char *OP_consts_h, *OP_consts_d, *OP_reduct_h, *OP_reduct_d;


//
// OP functions
//

void op_init(int argc, char **argv, int diags){
  cutilDeviceInit(argc, argv);
  OP_diags = diags;

#ifdef OP_BLOCK_SIZE
  OP_block_size = OP_BLOCK_SIZE;
#endif
#ifdef OP_PART_SIZE
  OP_part_size = OP_PART_SIZE;
#endif

  for (int n=1; n<argc; n++) {
    if (strncmp(argv[n],"OP_BLOCK_SIZE=",14)==0) {
      OP_block_size = atoi(argv[n]+14);
      printf("\n OP_block_size = %d \n", OP_block_size);
    }
    if (strncmp(argv[n],"OP_PART_SIZE=",13)==0) {
      OP_part_size = atoi(argv[n]+13);
      printf("\n OP_part_size  = %d \n", OP_part_size);
    }
    if (strncmp(argv[n],"OP_CACHE_LINE_SIZE=",19)==0) {
      OP_cache_line_size = atoi(argv[n]+19);
      printf("\n OP_cache_line_size  = %d \n", OP_cache_line_size);
    }
  }

#ifndef OP_x86
  #if CUDART_VERSION < 3020
    #error : "must be compiled using CUDA 3.2 or later"
  #endif

  #ifdef CUDA_NO_SM_13_DOUBLE_INTRINSICS
    #warning : " *** no support for double precision arithmetic *** "
  #endif

  cutilSafeCall(cudaThreadSetCacheConfig(cudaFuncCachePreferShared));
  printf("\n 16/48 L1/shared \n");
#endif

  for (int n=0; n<OP_KERNELS_MAX; n++) {
    OP_kernels[n].count     = 0;
    OP_kernels[n].transfer  = 0.0f;
    OP_kernels[n].transfer2 = 0.0f;
  }
}

void op_decl_set(int size, op_set &set, char const *name){

  if (size<=0) {
    printf(" op_decl_set error -- negative/zero size for set: %s\n",name);
    exit(-1);
  }

  set.size  = size;
  set.name  = name;
  set.index = OP_set_index;

  if (OP_set_index==OP_set_max) {
    OP_set_max += 10;
    OP_set_list = (op_set **) realloc(OP_set_list,OP_set_max*sizeof(op_set *));
    if (OP_set_list==NULL) {
      printf(" op_decl_set error -- error reallocating memory\n");
      exit(-1);  
    }
  }

  OP_set_list[OP_set_index++] = &set;
}

void op_decl_map(op_set from, op_set to, int dim, int *map, op_map &mapping, char const *name){

  if ( (from.index<0) || (from.index>=OP_set_index) ||
       strcmp((*(OP_set_list[from.index])).name,from.name) ) {
    printf(" op_decl_map error -- invalid 'from' set for map %s\n",name);
    exit(-1);
  }

  if ( (to.index<0) || (to.index>=OP_set_index) ||
       strcmp((*(OP_set_list[to.index])).name,to.name) ) {
    printf("op_decl_map error -- invalid 'to' set for map %s\n",name);
    exit(-1);
  }

  if (dim<=0) {
    printf("op_decl_map error -- negative/zero dimension for map %s\n",name);
    exit(-1);
  }

  for (int d=0; d<dim; d++) {
    for (int n=0; n<from.size; n++) {
      if (map[d+n*dim]<0 || map[d+n*dim]>=to.size) {
        printf("op_decl_map error -- invalid data for map %s\n",name);
        printf("element = %d, dimension = %d, map = %d\n",n,d,map[d+n*dim]);
        exit(-1);
      }
    }
  }

  mapping.from  = from;
  mapping.to    = to;
  mapping.dim   = dim;
  mapping.map   = map;
  mapping.name  = name;
  mapping.index = OP_map_index;

  if (OP_map_index==OP_map_max) {
    OP_map_max += 10;
    OP_map_list = (op_map **) realloc(OP_map_list,OP_map_max*sizeof(op_map *));
    if (OP_map_list==NULL) {
      printf(" op_decl_map error -- error reallocating memory\n");
      exit(-1);  
    }
  }

  OP_map_list[OP_map_index++] = &mapping;
}

void op_decl_dat_char(op_set set, int dim, char const *type, int size, char *dat, op_dat &data, char const *name){

  if ( (set.index<0) || (set.index>=OP_set_index) ||
       strcmp((*(OP_set_list[set.index])).name,set.name) ) {
    printf("op_decl_dat error -- invalid set for data: %s\n",name);
    exit(-1);
  }

  if (dim<=0) {
    printf("op_decl_dat error -- negative/zero dimension for data: %s\n",name);
    exit(-1);
  }

  data.set   = set;
  data.dim   = dim;
  data.dat   = dat;
  data.name  = name;
  data.type  = type;
  data.size  = dim*size;
  data.index = OP_dat_index;

  if (OP_dat_index==OP_dat_max) {
    OP_dat_max += 10;
    OP_dat_list = (op_dat **) realloc(OP_dat_list,OP_dat_max*sizeof(op_dat *));
    if (OP_dat_list==NULL) {
      printf(" op_decl_dat error -- error reallocating memory\n");
      exit(-1);  
    }
  }

  OP_dat_list[OP_dat_index++] = &data;

#ifndef OP_x86
  cutilSafeCall(cudaMalloc((void **)&data.dat_d, data.size*set.size));
  cutilSafeCall(cudaMemcpy(data.dat_d, data.dat, data.size*set.size,
                cudaMemcpyHostToDevice));
  cutilSafeCall(cudaThreadSynchronize());
#endif
}

//
// void op_decl_const_char  -- now defined in op_seq.cpp or *_kernels.cu
//

void op_diagnostic_output(){
  if (OP_diags > 1) {
    printf("\n  OP diagnostic output\n");
    printf(  "  --------------------\n");

    printf("\n       set       size\n");
    printf(  "  -------------------\n");
    for(int n=0; n<OP_set_index; n++) {
      op_set set=*OP_set_list[n];
      printf("%10s %10d\n",set.name,set.size);
    }

    printf("\n       map        dim       from         to\n");
    printf(  "  -----------------------------------------\n");
    for(int n=0; n<OP_map_index; n++) {
      op_map map=*OP_map_list[n];
      printf("%10s %10d %10s %10s\n",map.name,map.dim,map.from.name,map.to.name);
    }

    printf("\n       dat        dim        set\n");
    printf(  "  ------------------------------\n");
    for(int n=0; n<OP_dat_index; n++) {
      op_dat dat=*OP_dat_list[n];
      printf("%10s %10d %10s\n",dat.name,dat.dim,dat.set.name);
    }
    printf("\n");
  }
}

void op_timing_output() {
  printf("\n  count     time     GB/s     GB/s   kernel name ");
  printf("\n ----------------------------------------------- \n");
  for (int n=0; n<OP_KERNELS_MAX; n++) {
    if (OP_kernels[n].count>0) {
      if (OP_kernels[n].transfer2==0.0f)
        printf(" %6d  %8.4f %8.4f            %s \n",
	     OP_kernels[n].count,
             OP_kernels[n].time,
             OP_kernels[n].transfer/(1e9f*OP_kernels[n].time),
             OP_kernels[n].name);
      else
        printf(" %6d  %8.4f %8.4f %8.4f   %s \n",
	     OP_kernels[n].count,
             OP_kernels[n].time,
             OP_kernels[n].transfer/(1e9f*OP_kernels[n].time),
             OP_kernels[n].transfer2/(1e9f*OP_kernels[n].time),
             OP_kernels[n].name);
    }
  }
}


void op_exit(){
}


//
// comparison function for integer quicksort
//

int comp(const void *a2, const void *b2) {
  int *a = (int *)a2;
  int *b = (int *)b2;

  if (*a == *b)
    return 0;
  else
    if (*a < *b)
      return -1;
    else
      return 1;
}


//
// next few routines are CUDA-specific
//

#ifndef OP_x86

//
// utility routine to move arrays to GPU device
//

template <class T>
void mvHostToDevice(T **map, int size) {
  T *tmp;
  cutilSafeCall(cudaMalloc((void **)&tmp, size));
  cutilSafeCall(cudaMemcpy(tmp, *map, size, cudaMemcpyHostToDevice));
  cutilSafeCall(cudaThreadSynchronize());
  free(*map);
  *map = tmp;
}


//
// utility routine to copy dataset back to host
//

extern void op_fetch_data(op_dat data) {
  cutilSafeCall(cudaMemcpy(data.dat, data.dat_d, data.size*data.set.size,
                cudaMemcpyDeviceToHost));
  cutilSafeCall(cudaThreadSynchronize());
}


//
// utility routines to resize constant/reduct arrays, if necessary
//

void reallocConstArrays(int consts_bytes) {
  if (consts_bytes>OP_consts_bytes) {
    if (OP_consts_bytes>0) {
      free(OP_consts_h);
      cutilSafeCall(cudaFree(OP_consts_d));
    }
    OP_consts_bytes = 4*consts_bytes;
    OP_consts_h = (char *) malloc(OP_consts_bytes);
    cutilSafeCall(cudaMalloc((void **)&OP_consts_d, OP_consts_bytes));
  }
}

void reallocReductArrays(int reduct_bytes) {
  if (reduct_bytes>OP_reduct_bytes) {
    if (OP_reduct_bytes>0) {
      free(OP_reduct_h);
      cutilSafeCall(cudaFree(OP_reduct_d));
    }
    OP_reduct_bytes = 4*reduct_bytes;
    OP_reduct_h = (char *) malloc(OP_reduct_bytes);
    cutilSafeCall(cudaMalloc((void **)&OP_reduct_d, OP_reduct_bytes));
    // printf("\n allocated %d bytes for reduction arrays \n",OP_reduct_bytes);
  }
}

//
// utility routine to move constant/reduct arrays
//

void mvConstArraysToDevice(int consts_bytes) {
  cutilSafeCall(cudaMemcpy(OP_consts_d, OP_consts_h, consts_bytes,
                cudaMemcpyHostToDevice));
  cutilSafeCall(cudaThreadSynchronize());
}

void mvReductArraysToDevice(int reduct_bytes) {
  cutilSafeCall(cudaMemcpy(OP_reduct_d, OP_reduct_h, reduct_bytes,
                cudaMemcpyHostToDevice));
  cutilSafeCall(cudaThreadSynchronize());
}

void mvReductArraysToHost(int reduct_bytes) {
  cutilSafeCall(cudaMemcpy(OP_reduct_h, OP_reduct_d, reduct_bytes,
                cudaMemcpyDeviceToHost));
  cutilSafeCall(cudaThreadSynchronize());
}


//
// reduction routine for arbitrary datatypes
//

__device__ int OP_reduct_lock=0;  // important: must be initialised to 0


template < op_access reduction, class T >
__inline__ __device__ void op_reduction(volatile T *dat_g, T dat_l)
{
  int tid = threadIdx.x;
  int d   = blockDim.x>>1; 
  extern __shared__ T temp[];

  __syncthreads();  // important to finish all previous activity

  temp[tid] = dat_l;

  for (; d>warpSize; d>>=1) {
    __syncthreads();
    if (tid<d) {
      switch (reduction) {
      case OP_INC:
        temp[tid] = temp[tid] + temp[tid+d];
        break;
      case OP_MIN:
        if(temp[tid+d]<temp[tid]) temp[tid] = temp[tid+d];
        break;
      case OP_MAX:
        if(temp[tid+d]>temp[tid]) temp[tid] = temp[tid+d];
        break;
      }
    }
  }

  __syncthreads();

  volatile T *vtemp = temp;   // see Fermi compatibility guide 

  if (tid<warpSize) {
    for (; d>0; d>>=1) {
      if (tid<d) {
        switch (reduction) {
        case OP_INC:
          vtemp[tid] = vtemp[tid] + vtemp[tid+d];
          break;
        case OP_MIN:
          if(vtemp[tid+d]<vtemp[tid]) vtemp[tid] = vtemp[tid+d];
          break;
        case OP_MAX:
          if(vtemp[tid+d]>vtemp[tid]) vtemp[tid] = vtemp[tid+d];
          break;
        }
      }
    }
  }

  if (tid==0) {
    // do {} while(atomicCAS(&OP_reduct_lock,0,1));  // set lock

    switch (reduction) {
    case OP_INC:
      *dat_g = *dat_g + vtemp[0];
      break;
    case OP_MIN:
      if(temp[0]<*dat_g) *dat_g = vtemp[0];
      break;
    case OP_MAX:
      if(temp[0]>*dat_g) *dat_g = vtemp[0];
      break;
    }

    // __threadfence();                // ensure *dat_g update complete
    // OP_reduct_lock = 0;             // free lock
  }

}


#endif

//
// little utility to test for matching types
//

inline int type_match(char const *typ1, char const *typ2){
  return (strcmp(typ1,typ2)==0);
}


//
// declaration of plan check routine
//

void OP_plan_check(op_plan, int, int *);


//
// find existing execution plan, or construct a new one
//

extern op_plan * plan(char const * name, op_set set, int nargs, op_dat *args, int *idxs,
      op_map *maps, int *dims, char const **typs, op_access *accs, int ninds, int *inds){

  // first look for an existing execution plan

  int ip=0, match=0;

  while (match==0 && ip<OP_plan_index) {
    if ( (strcmp(name,        OP_plans[ip].name)==0)
             && (set.index == OP_plans[ip].set_index)
             && (nargs     == OP_plans[ip].nargs) ) {
      match = 1;
      for (int m=0; m<nargs; m++) {
        match = match && (args[m].index == OP_plans[ip].arg_idxs[m])
                      && (idxs[m]       == OP_plans[ip].idxs[m])
                      && (maps[m].index == OP_plans[ip].map_idxs[m])
                      && (dims[m]       == OP_plans[ip].dims[m])
            && type_match(typs[m],         OP_plans[ip].typs[m])
                      && (accs[m]       == OP_plans[ip].accs[m]);
      }
    }
    ip++;
  }

  if (match) {
    ip--;
    if (OP_diags > 3) printf(" old execution plan #%d\n",ip);
    return &(OP_plans[ip]);
  }
  else {
    if (OP_diags > 1) printf(" new execution plan #%d for kernel %s\n",ip,name);
  }

  // consistency checks

  if (OP_diags > 0) {
    for (int m=0; m<nargs; m++) {
      if (idxs[m] == -1) {
        //if (maps[m].index != -1) {
        if (maps[m].map != NULL) {
          printf("error2: wrong mapping for arg %d in kernel \"%s\"\n",m,name);
          printf("maps[m].index = %d\n",maps[m].index);
          printf("maps[m].name  = %s\n",maps[m].name);
          exit(1);
        }
      }
      else {
        if (set.index         != maps[m].from.index ||
            args[m].set.index != maps[m].to.index) {
          printf("error: wrong mapping for arg %d in kernel \"%s\"\n",m,name);
          exit(1);
        }
        if (maps[m].dim <= idxs[m]) {
          printf(" %d %d",maps[m].dim,idxs[m]);
          printf("error: invalid mapping index for arg %d in kernel \"%s\"\n",m,name);
          exit(1);
        }
      }
      if (!type_match(args[m].type,typs[m])) {
        printf("error: wrong datatype for arg %d in kernel \"%s\"\n",m,name);
        exit(1);
      }
      if (args[m].dim != dims[m] && args[m].set.size>0) {
        printf("error: wrong dimension for arg %d in kernel \"%s\"\n",m,name);
        exit(1);
      }
    }
  }

  // work out worst case shared memory requirement per element

  int maxbytes = 0;
  for (int m=0; m<nargs; m++) {
    if (inds[m]>=0) maxbytes += args[m].size;
  }

  // set blocksize and number of blocks;
  // adaptive size based on 48kB of shared memory

  int bsize   = OP_part_size;   // blocksize
  if (bsize==0) bsize = (48*1024/(64*maxbytes))*64;
  int nblocks = (set.size-1)/bsize + 1;

  // enlarge OP_plans array if needed

  if (ip==OP_plan_max) {
    // printf("allocating more memory for OP_plans \n");
    OP_plan_max += 10;
    OP_plans = (op_plan *) realloc(OP_plans,OP_plan_max*sizeof(op_plan));
    if (OP_plans==NULL) {
      printf(" op_plan error -- error reallocating memory for OP_plans\n");
      exit(-1);  
    }
  }

  // allocate memory for new execution plan and store input arguments

  OP_plans[ip].arg_idxs  = (int *)malloc(nargs*sizeof(int));
  OP_plans[ip].idxs      = (int *)malloc(nargs*sizeof(int));
  OP_plans[ip].map_idxs  = (int *)malloc(nargs*sizeof(int));
  OP_plans[ip].dims      = (int *)malloc(nargs*sizeof(int));
  OP_plans[ip].typs      = (char const **)malloc(nargs*sizeof(char *));
  OP_plans[ip].accs      = (op_access *)malloc(nargs*sizeof(op_access));

  OP_plans[ip].nthrcol   = (int *)malloc(nblocks*sizeof(int));
  OP_plans[ip].thrcol    = (int *)malloc(set.size*sizeof(int));
  OP_plans[ip].offset    = (int *)malloc(nblocks*sizeof(int));
  OP_plans[ip].ind_maps  = (int **)malloc(ninds*sizeof(int *));
  OP_plans[ip].ind_offs  = (int *)malloc(nblocks*ninds*sizeof(int));
  OP_plans[ip].ind_sizes = (int *)malloc(nblocks*ninds*sizeof(int));
  OP_plans[ip].maps      = (short **)malloc(nargs*sizeof(short *));
  OP_plans[ip].nelems    = (int *)malloc(nblocks*sizeof(int));
  OP_plans[ip].ncolblk   = (int *)calloc(set.size,sizeof(int)); // max possibly needed
  OP_plans[ip].blkmap    = (int *)calloc(nblocks,sizeof(int));

  for (int m=0; m<ninds; m++) {
    int count = 0;
    for (int m2=0; m2<nargs; m2++)
      if (inds[m2]==m) count++;
    OP_plans[ip].ind_maps[m]  = (int *)malloc(count*set.size*sizeof(int));
  }

  for (int m=0; m<nargs; m++) {
    OP_plans[ip].maps[m]     = (short *)malloc(set.size*sizeof(short));

    OP_plans[ip].arg_idxs[m] = args[m].index;
    OP_plans[ip].idxs[m]     = idxs[m];
    OP_plans[ip].map_idxs[m] = maps[m].index;
    OP_plans[ip].dims[m]     = dims[m];
    OP_plans[ip].typs[m]     = typs[m];
    OP_plans[ip].accs[m]     = accs[m];
  }

  OP_plans[ip].name      = name;
  OP_plans[ip].set_index = set.index;
  OP_plans[ip].nargs     = nargs;
    
  OP_plan_index++;

  // allocate working arrays

  uint **work;
  work = (uint **)malloc(ninds*sizeof(uint *));

  for (int m=0; m<ninds; m++) {
    int m2 = 0;
    while(inds[m2]!=m) m2++;

    work[m] = (uint *)malloc(maps[m2].to.size*sizeof(uint));
  }

  int *work2;
  work2 = (int *)malloc(nargs*bsize*sizeof(int));  // max possibly needed

  // process set one block at a time

  int *nindirect;
  nindirect = (int *)calloc(ninds,sizeof(int));  // total number of indirect elements

  double total_colors = 0;

  for (int b=0; b<nblocks; b++) {
    int bs = MIN(bsize, set.size - b*bsize);

    OP_plans[ip].offset[b] = b*bsize;    // offset for block
    OP_plans[ip].nelems[b] = bs;         // size of block

    // loop over indirection sets

    for (int m=0; m<ninds; m++) {

      // build the list of elements indirectly referenced in this block

      int ne = 0;  // number of elements
      for (int m2=0; m2<nargs; m2++) {
        if (inds[m2]==m) {
          for (int e=b*bsize; e<b*bsize+bs; e++)
            work2[ne++] = maps[m2].map[idxs[m2]+e*maps[m2].dim];
	}
      }

      // sort them, then eliminate duplicates

      qsort(work2,ne,sizeof(int),comp);
        
      int e = 0;
      int p = 0;
      while (p<ne) {
        work2[e] = work2[p];
        while (p<ne && work2[p]==work2[e]) p++;
        e++;
      }
      ne = e;  // number of distinct elements

      /*
      if (OP_diags > 5) {
        printf(" indirection set %d: ",m);
        for (int e=0; e<ne; e++) printf(" %d",work2[e]);
        printf(" \n");
      }
      */


      // store mapping and renumbered mappings in execution plan

      for (int e=0; e<ne; e++) {
        OP_plans[ip].ind_maps[m][nindirect[m]++] = work2[e];
        work[m][work2[e]] = e;   // inverse mapping
      }

      for (int m2=0; m2<nargs; m2++) {
        if (inds[m2]==m) {
          for (int e=b*bsize; e<b*bsize+bs; e++)
            OP_plans[ip].maps[m2][e] = work[m][maps[m2].map[idxs[m2]+e*maps[m2].dim]];
	}
      }

      if (b==0) {
        OP_plans[ip].ind_offs[m+b*ninds]  = 0;
        OP_plans[ip].ind_sizes[m+b*ninds] = nindirect[m];
      }
      else {
        OP_plans[ip].ind_offs[m+b*ninds]  = OP_plans[ip].ind_offs[m+(b-1)*ninds]
                                          + OP_plans[ip].ind_sizes[m+(b-1)*ninds];
        OP_plans[ip].ind_sizes[m+b*ninds] = nindirect[m]
                                          - OP_plans[ip].ind_offs[m+b*ninds];
      }
    }


    // print out re-numbered mappings

    /*
    for (int m=0; m<nargs; m++) {
      if (inds[m]>=0) {
        printf(" mapping table %d\n",m);
        for (int e=0; e<set.size; e++)
          printf(" map = %d\n",OP_plans[ip].maps[m][e]);
      }
    }

    for (int m=0; m<ninds; m++) {
      printf(" indirect set %d\n",m);
      for (int b=0; b<nblocks; b++) {
        printf("OP_plans[ip].ind_sizes[m+b*ninds] = %d\n",
                OP_plans[ip].ind_sizes[m+b*ninds]);
        printf("OP_plans[ip].ind_offs[m+b*ninds] = %d\n",
                OP_plans[ip].ind_offs[m+b*ninds]);
      }
    }
    */

    // now colour main set elements

    for (int e=b*bsize; e<b*bsize+bs; e++) OP_plans[ip].thrcol[e]=-1;

    int repeat  = 1;
    int ncolor  = 0;
    int ncolors = 0;

    while (repeat) {
      repeat = 0;

      for (int m=0; m<nargs; m++) {
        if (inds[m]>=0)
          for (int e=b*bsize; e<b*bsize+bs; e++)
            work[inds[m]][maps[m].map[idxs[m]+e*maps[m].dim]] = 0;  // zero out color array
      }

      for (int e=b*bsize; e<b*bsize+bs; e++) {
        if (OP_plans[ip].thrcol[e] == -1) {
          int mask = 0;
          for (int m=0; m<nargs; m++)
            if (inds[m]>=0 && accs[m]==OP_INC)
              mask |= work[inds[m]][maps[m].map[idxs[m]+e*maps[m].dim]]; // set bits of mask

          int color = ffs(~mask) - 1;   // find first bit not set
          if (color==-1) {              // run out of colors on this pass
            repeat = 1;
          }
          else {
            OP_plans[ip].thrcol[e] = ncolor+color;
            mask    = 1 << color;
            ncolors = MAX(ncolors, ncolor+color+1);

            for (int m=0; m<nargs; m++)
              if (inds[m]>=0 && accs[m]==OP_INC)
                work[inds[m]][maps[m].map[idxs[m]+e*maps[m].dim]] |= mask; // set color bit
          }
        }
      }

      ncolor += 32;   // increment base level
    }

    OP_plans[ip].nthrcol[b] = ncolors;  // number of thread colors in this block
    total_colors += ncolors;

    // if(ncolors>1) printf(" number of colors in this block = %d \n",ncolors);

    // reorder elements by color?

  }


  // colour the blocks, after initialising colors to 0

  int *blk_col;
  blk_col = (int *) malloc(nblocks*sizeof(int));
  for (int b=0; b<nblocks; b++) blk_col[b] = -1;

  int repeat  = 1;
  int ncolor  = 0;
  int ncolors = 0;

  while (repeat) {
    repeat = 0;

    for (int m=0; m<nargs; m++) {
      if (inds[m]>=0) 
        for (int e=0; e<maps[m].to.size; e++)
          work[inds[m]][e] = 0;               // zero out color arrays
    }

    for (int b=0; b<nblocks; b++) {
      if (blk_col[b] == -1) {          // color not yet assigned to block
        int  bs   = MIN(bsize, set.size - b*bsize);
        uint mask = 0;

        for (int m=0; m<nargs; m++) {
          if (inds[m]>=0 && accs[m]==OP_INC) 
            for (int e=b*bsize; e<b*bsize+bs; e++)
              mask |= work[inds[m]][maps[m].map[idxs[m]+e*maps[m].dim]]; // set bits of mask
        }

        int color = ffs(~mask) - 1;   // find first bit not set
        if (color==-1) {              // run out of colors on this pass
          repeat = 1;
        }
        else {
          blk_col[b] = ncolor + color;
          mask    = 1 << color;
          ncolors = MAX(ncolors, ncolor+color+1);

          for (int m=0; m<nargs; m++) {
            if (inds[m]>=0 && accs[m]==OP_INC)
              for (int e=b*bsize; e<b*bsize+bs; e++)
                work[inds[m]][maps[m].map[idxs[m]+e*maps[m].dim]] |= mask;
          }
        }
      }
    }

    ncolor += 32;   // increment base level
  }

  // store block mapping and number of blocks per color


  OP_plans[ip].ncolors = ncolors;

  for (int b=0; b<nblocks; b++)
    OP_plans[ip].ncolblk[blk_col[b]]++;  // number of blocks of each color

  for (int c=1; c<ncolors; c++)
    OP_plans[ip].ncolblk[c] += OP_plans[ip].ncolblk[c-1]; // cumsum

  for (int c=0; c<ncolors; c++) work2[c]=0;

  for (int b=0; b<nblocks; b++) {
    int c  = blk_col[b];
    int b2 = work2[c];     // number of preceding blocks of this color
    if (c>0) b2 += OP_plans[ip].ncolblk[c-1];  // plus previous colors

    OP_plans[ip].blkmap[b2] = b;

    work2[c]++;            // increment counter
  }

  for (int c=ncolors-1; c>0; c--)
    OP_plans[ip].ncolblk[c] -= OP_plans[ip].ncolblk[c-1]; // undo cumsum

  // reorder blocks by color?


  // work out shared memory requirements

  OP_plans[ip].nshared = 0;
  double total_shared = 0;

  for (int b=0; b<nblocks; b++) {
    int nbytes = 0;
    for (int m=0; m<ninds; m++) {
      int m2 = 0;
      while(inds[m2]!=m) m2++;

      nbytes += ROUND_UP(OP_plans[ip].ind_sizes[m+b*ninds]*args[m2].size);
    }
    OP_plans[ip].nshared = MAX(OP_plans[ip].nshared,nbytes);
    total_shared += nbytes;
  }

  // work out total bandwidth requirements

  OP_plans[ip].transfer  = 0;
  OP_plans[ip].transfer2 = 0;

  for (int b=0; b<nblocks; b++) {
    for (int m=0; m<nargs; m++) {
      if (inds[m]<0) {
        double fac = 2.0f;
        if (accs[m]==OP_READ) fac = 1.0f;
        OP_plans[ip].transfer  += fac*OP_plans[ip].nelems[b]*args[m].size;
        OP_plans[ip].transfer2 += fac*OP_plans[ip].nelems[b]*args[m].size;
      }
      else {
        OP_plans[ip].transfer  += OP_plans[ip].nelems[b]*sizeof(short);
        OP_plans[ip].transfer2 += OP_plans[ip].nelems[b]*sizeof(short);
      }
    }
    for (int m=0; m<ninds; m++) {
      int m2 = 0;
      while(inds[m2]!=m) m2++;
      double fac = 2.0f;
      if (accs[m2]==OP_READ) fac = 1.0f;
      OP_plans[ip].transfer += fac*OP_plans[ip].ind_sizes[m+b*ninds]*args[m2].size;

      // work out how many cache lines are used by indirect addressing

      int i_map, l_new, l_old=-1;
      int e0 = OP_plans[ip].ind_offs[m+b*ninds];
      int e1 = e0 + OP_plans[ip].ind_sizes[m+b*ninds];

      for (int e=e0; e<e1; e++) {
        i_map = OP_plans[ip].ind_maps[m][e];
        l_new = (i_map*args[m2].size)/OP_cache_line_size;
        if (l_new>l_old) OP_plans[ip].transfer2 += fac*OP_cache_line_size;
        l_old = l_new;
        l_new = ((i_map+1)*args[m2].size-1)/OP_cache_line_size;
        OP_plans[ip].transfer2 += fac*(l_new-l_old)*OP_cache_line_size;
        l_old = l_new;
      }

      // also include mappings to load/store data

      fac = 1.0f;
      if (accs[m2]==OP_RW) fac = 2.0f;
      OP_plans[ip].transfer  += fac*OP_plans[ip].ind_sizes[m+b*ninds]*sizeof(int);
      OP_plans[ip].transfer2 += fac*OP_plans[ip].ind_sizes[m+b*ninds]*sizeof(int);
    }
  }

  // print out useful information

  if (OP_diags>1) {
    printf(" number of blocks       = %d \n",nblocks);
    printf(" number of block colors = %d \n",OP_plans[ip].ncolors);
    printf(" maximum block size     = %d \n",bsize);
    printf(" average thread colors  = %.2f \n",total_colors/nblocks);
    printf(" shared memory required = %.2f KB \n",OP_plans[ip].nshared/1024.0f);
    printf(" average data reuse     = %.2f \n",maxbytes*(set.size/total_shared));
    printf(" data transfer (used)   = %.2f MB \n",
                                       OP_plans[ip].transfer/(1024.0f*1024.0f));
    printf(" data transfer (total)  = %.2f MB \n\n",
                                       OP_plans[ip].transfer2/(1024.0f*1024.0f));
  }

  // validate plan info

  OP_plan_check(OP_plans[ip],ninds,inds);

  // move plan arrays to GPU

  for (int m=0; m<ninds; m++) {
    mvHostToDevice(&(OP_plans[ip].ind_maps[m]), sizeof(int)*nindirect[m]);
  }

  for (int m=0; m<nargs; m++) {
    if (inds[m]>=0)
      mvHostToDevice(&(OP_plans[ip].maps[m]), sizeof(short)*set.size);
  }

  mvHostToDevice(&(OP_plans[ip].ind_sizes),sizeof(int)*nblocks*ninds);
  mvHostToDevice(&(OP_plans[ip].ind_offs), sizeof(int)*nblocks*ninds);
  mvHostToDevice(&(OP_plans[ip].nthrcol),sizeof(int)*nblocks);
  mvHostToDevice(&(OP_plans[ip].thrcol ),sizeof(int)*set.size);
  mvHostToDevice(&(OP_plans[ip].offset ),sizeof(int)*nblocks);
  mvHostToDevice(&(OP_plans[ip].nelems ),sizeof(int)*nblocks);
  mvHostToDevice(&(OP_plans[ip].blkmap ),sizeof(int)*nblocks);

  // free work arrays

  for (int m=0; m<ninds; m++) free(work[m]);
  free(work);
  free(work2);
  free(blk_col);
  free(nindirect);

  // return pointer to plan

  return &(OP_plans[ip]);
}


void OP_plan_check(op_plan OP_plan, int ninds, int *inds) {

  int err, ntot;

  op_set set = *OP_set_list[OP_plan.set_index];

  int nblock = 0;
  for (int col=0; col<OP_plan.ncolors; col++) nblock += OP_plan.ncolblk[col];

  //
  // check total size
  //

  int nelem = 0;
  for (int n=0; n<nblock; n++) nelem += OP_plan.nelems[n];

  if (nelem != set.size) {
    printf(" *** OP_plan_check: nelems error \n");
  }
  else if (OP_diags>6) {
    printf(" *** OP_plan_check: nelems   OK \n");
  }

  //
  // check offset and nelems are consistent
  //

  err  = 0;
  ntot = 0;

  for (int n=0; n<nblock; n++) {
    err  += (OP_plan.offset[n] != ntot);
    ntot +=  OP_plan.nelems[n];
  }

  if (err != 0) {
    printf(" *** OP_plan_check: offset error \n");
  }
  else if (OP_diags>6) {
    printf(" *** OP_plan_check: offset   OK \n");
  }

  //
  // check blkmap permutation
  //

  int *blkmap = (int *) malloc(nblock*sizeof(int));
  for (int n=0; n<nblock; n++) blkmap[n] = OP_plan.blkmap[n];
  qsort(blkmap,nblock,sizeof(int),comp);

  err = 0;
  for (int n=0; n<nblock; n++) err += (blkmap[n] != n);

  free(blkmap);

  if (err != 0) {
    printf(" *** OP_plan_check: blkmap error \n");
  }
  else if (OP_diags>6) {
    printf(" *** OP_plan_check: blkmap   OK \n");
  }

  //
  // check ind_offs and ind_sizes are consistent
  //

  err  = 0;

  for (int i = 0; i<ninds; i++) {
    ntot = 0;

    for (int n=0; n<nblock; n++) {
      err  += (OP_plan.ind_offs[i+n*ninds] != ntot);
      ntot +=  OP_plan.ind_sizes[i+n*ninds];
    }
  }

  if (err != 0) {
    printf(" *** OP_plan_check: ind_offs error \n");
  }
  else if (OP_diags>6) {
    printf(" *** OP_plan_check: ind_offs OK \n");
  }

  //
  // check ind_maps correctly ordered within each block
  // and indices within range
  //

  err = 0;

  for (int m = 0; m<ninds; m++) {
    int m2 = 0;
    while(inds[m2]!=m) m2++;
    int set_size = (*OP_map_list[OP_plan.map_idxs[m2]]).to.size;

    ntot = 0;

    for (int n=0; n<nblock; n++) {
      int last = -1;
      for (int e=ntot; e<ntot+OP_plan.ind_sizes[m+n*ninds]; e++) {
        err  += (OP_plan.ind_maps[m][e] <= last);
        last  = OP_plan.ind_maps[m][e]; 
      }
      err  += (last >= set_size);
      ntot +=  OP_plan.ind_sizes[m+n*ninds];
    }
  }

  if (err != 0) {
    printf(" *** OP_plan_check: ind_maps error \n");
  }
  else if (OP_diags>6) {
    printf(" *** OP_plan_check: ind_maps OK \n");
  }

  //
  // check maps (most likely source of errors)
  //

  err = 0;

  for (int m=0; m<OP_plan.nargs; m++) {
    if (OP_plan.map_idxs[m]>=0) {
      op_map map = *OP_map_list[OP_plan.map_idxs[m]];
      int    m2  = inds[m];

      ntot = 0;
      for (int n=0; n<nblock; n++) {
        for (int e=ntot; e<ntot+OP_plan.nelems[n]; e++) {
          int p_local  = OP_plan.maps[m][e];
          int p_global = OP_plan.ind_maps[m2][p_local+OP_plan.ind_offs[m2+n*ninds]]; 

          err += (p_global != map.map[OP_plan.idxs[m]+e*map.dim]);
        }
        ntot +=  OP_plan.nelems[n];
      }
    }
  }

  if (err != 0) {
    printf(" *** OP_plan_check: maps error \n");
  }
  else if (OP_diags>6) {
    printf(" *** OP_plan_check: maps     OK \n");
  }


  //
  // check thread and block coloring
  //

  return;
}
