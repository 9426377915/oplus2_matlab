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


/* 
 * written by: Gihan R. Mudalige, 01-03-2011
 */

 
/*--------------------------MPI related datatypes-----------------------------*/

typedef struct {
 op_map	      map; //mapping table thats related to this export list
 int 	      size; //total size of this list
 int 	     *ranks; //MPI ranks to be exported to
 int	     ranks_size; //number of MPI neighbors for this map
 int         *disps; //displacements for the starting point of each rank's export list in exp_list
 int 	     *sizes;  //export list sizes for each ranks
 int 	     *exp_list;  //export list of all ranks 
} map_export_list;

typedef struct {
 op_set	      set; //set related to this export list 
 int 	      size; //total size of this list
 int 	     *ranks; //MPI ranks to be exported to
 int	     ranks_size; //number of MPI neighbors for this set
 int         *disps; //displacements for the starting point of each rank's export list in exp_list
 int 	     *sizes;  //export list sizes for each ranks
 int 	     *exp_list;  //export list of all ranks
} set_export_list;

typedef struct {
 op_map	      map; //mapping table thats related to this import list
 int 	      size; //total size of this list
 int 	     *ranks; //MPI ranks to be imported from
 int	     ranks_size; //number of MPI neighbors for this map
 int         *disps; //displacements for the starting point of each rank's import list in imp_list
 int 	     *sizes;  //import list sizes for each ranks
 int 	     *imp_list;  //import list of all ranks 
} map_import_list;

typedef struct {
 op_set	      set; //set related to this import list 
 int 	      size; //total size of this list
 int 	     *ranks; //MPI ranks to be imported from
 int	     ranks_size; //number of MPI neighbors for this set
 int         *disps; //displacements for the starting point of each rank's import list in imp_list
 int 	     *sizes;  //import list sizes for each ranks
 int 	     *imp_list;  //import list of all ranks
} set_import_list;

typedef struct {
 op_set	      set; //set related to this import list 
 int 	      size; //total size of this list
 int 	     *ranks; //MPI ranks to be imported from
 int	     ranks_size; //number of MPI neighbors for this set
 int         *disps; //displacements for the starting point of each rank's import list in imp_list
 int 	     *sizes;  //import list sizes for each ranks
 int 	     *imp_list;  //import list of all ranks
} nonexec_set_import_list;

typedef struct {
 op_set	      set; //set related to this export list 
 int 	      size; //total size of this list
 int 	     *ranks; //MPI ranks to be exported to
 int	     ranks_size; //number of MPI neighbors for this set
 int         *disps; //displacements for the starting point of each rank's export list in exp_list
 int 	     *sizes;  //export list sizes for each ranks
 int 	     *exp_list;  //export list of all ranks
} nonexec_set_export_list;


