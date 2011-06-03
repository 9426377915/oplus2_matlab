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
#include "op_datatypes.h"


//
// global variables
//

int OP_set_index=0,
    OP_map_index=0,
    OP_dat_index=0,
    OP_nplans   =0,
    OP_diags    =0;

op_set  * OP_set_list[10];
op_map  * OP_map_list[10];
op_dat  * OP_dat_list[10];
op_plan   OP_plans[100];
op_kernel OP_kernels[100];

//
// OP functions
//

void op_init(int argc, char **argv, int diags){
  OP_diags = diags;
  
}

void op_decl_set(int size, op_set &set, char const *name){
  set.size = size;
  set.name = name;

  set.index = OP_set_index;
  OP_set_list[OP_set_index++] = &set;
}

void op_decl_map(op_set from, op_set to, int dim, int *map, op_map &mapping, char const *name){
  mapping.from = from;
  mapping.to   = to;
  mapping.dim  = dim;
  mapping.map  = map;
  mapping.name = name;

  mapping.index = OP_map_index;
  OP_map_list[OP_map_index++] = &mapping;
}

void op_decl_dat_char(op_set set, int dim, char const *type, int size, char *dat, op_dat &data, char const *name){
  data.set   = set;
  data.dim   = dim;
  data.dat   = dat;
  data.name  = name;
  data.type  = type;
  data.size  = dim*size;
  data.index = OP_dat_index;
  OP_dat_list[OP_dat_index++] = &data;
}

void op_decl_const_char(int dim, char const *type, int size, char *dat, char const *name){
}

void op_fetch_data(op_dat dat){
}

void op_diagnostic_output(){
    
    int my_rank;
    MPI_Comm_rank(MPI_COMM_WORLD, &my_rank);
    
    if (OP_diags > 1) {
    	printf("\n  OP diagnostic output on rank %d\n", my_rank);
    	printf(  "  ---------------------------------\n");
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
    	}    printf("\n");
    }
}

void op_exit(){
}
