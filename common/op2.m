%
% Source code transformation tool
%
% This tool parses the user's original source code
% to produce the CUDA code which will execute the
% user's kernel functions.
%
% The main deficiency of this current implementation
% is that it does not handle cases in which multiple 
% arguments involve the same underlying dataset.
%
% This prototype is written in MATLAB but a future
% version may use Python to avoid licensing costs.
% Alternatively, the MATLAB processor can be 
% "compiled" to produce a standalone version which
% can be freely distributed.
%
%
% usage: op2('filename')
%
% This takes as input 
%
% filename.cpp
%
% and produces as output
%
% filename_op.cpp
% filename_kernels.cu
%
% and one or more files of the form
%
% xxx_kernel.cu
%
% where xxx corresponds to the name of one of the
% kernel functions in filename.cpp
%

function op2(varargin)

global dims idxs typs indtyps inddims

%
% declare constants
%

OP_CUDA = 1;
OP_x86  = 2;

OP_targets = [ OP_CUDA OP_x86 ];

OP_ID  = 1;
OP_GBL = 2;
OP_PTR = 3;

OP_ptrs_labels = { 'OP_ID' 'OP_GBL' 'OP_PTR' };

OP_READ  = 1;
OP_WRITE = 2;
OP_RW    = 3;
OP_INC   = 4;
OP_MAX   = 5;
OP_MIN   = 6;

OP_accs_labels = { 'OP_READ' 'OP_WRITE' 'OP_RW' 'OP_INC' 'OP_MAX' 'OP_MIN' };

date = datestr(now);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  outer loop over all backend targets
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for target = OP_targets


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  loop over all input source files
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

nker = -1;

for narg = 1: nargin
  nkernels = 0;

  filename = varargin{narg};
  disp(sprintf('\nprocessing file %d of %d (%s)',narg,nargin,[filename '.cpp']));

  new_file = fileread([filename '.cpp']);
  src_file = regexprep(new_file,'\s','');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  parse file for next op_par_loop
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  while (~isempty(strfind(src_file,'op_par_loop_')))

    loc  = min(strfind(src_file,'op_par_loop_'));
    src_file = src_file(loc+12:end);

    [num,  src_file] = strtok(src_file,'(');
    nargs = str2num(num);
    [src_args, src_file] = strtok(src_file,')');
    src_args = src_args(2:end);

    loc = [0 strfind(src_args,',') length(src_args)+1];

    na = length(loc)-1;

    if (na ~= 3+6*nargs)
      error(sprintf('wrong number of arguments: expected %d, found %d',3+6*nargs, na));
    end

    for n = 1:na
      C{n} = src_args(loc(n)+1:loc(n+1)-1);
    end

    nkernels = nkernels + 1;
    nker     = nker + 1;
    fn_name  = C{1};
    disp(sprintf('\n  processing kernel %d (%s) with %d arguments',nkernels,fn_name,nargs));

%
% process parameters
%

    idxs = zeros(1,nargs);
    dims = {};
    ptrs = zeros(1,nargs);
    typs = {};
    accs = zeros(1,nargs);

    for m = 1:nargs
      idxs(m) = str2num(C{-1+6*m});
      dims{m} = C{ 1+6*m};

      if(isempty(strmatch(C{6*m},OP_ptrs_labels)))
        ptrs(m) = OP_PTR;
        if(idxs(m)<0)
          error(sprintf('invalid index for argument %d',m));
        end
      else
        ptrs(m) = strmatch(C{6*m},OP_ptrs_labels);
        if(idxs(m)~=-1)
          error(sprintf('invalid index for argument %d',m));
        end
      end

      typs{m} = C{2+6*m}(2:end-1);

      if(isempty(strmatch(C{3+6*m},OP_accs_labels)))
        error(sprintf('unknown access type for argument %d',m));
      else
        accs(m) = strmatch(C{3+6*m},OP_accs_labels);
      end

      if(ptrs(m)==OP_GBL & (accs(m)==OP_WRITE | accs(m)==OP_RW))
        error(sprintf('invalid access type for argument %d',m));
      end

      if(ptrs(m)~=OP_GBL & (accs(m)==OP_MIN | accs(m)==OP_MAX))
        error(sprintf('invalid access type for argument %d',m));
      end

    end

%
% set two logicals 
%

%    ind_inc = length(find(idxs>=0 & accs==OP_INC)) > 0;

   ind_inc = max(ptrs==OP_PTR & accs==OP_INC)  > 0;
   reduct  = max(ptrs==OP_GBL & accs~=OP_READ) > 0;

%
%  identify indirect datasets
%

    ninds     = 0;
    invinds   = zeros(1,nargs);
    inds      = zeros(1,nargs);
    indtyps   = cell(1,nargs);
    inddims   = cell(1,nargs);
    indaccs   = zeros(1,nargs);

%    j = find(idxs>=0);                % find all indirect arguments
    j = find(ptrs==OP_PTR);                % find all indirect arguments

    while (~isempty(j))
      match = strcmp(C(-2+6*j(1)), C(-2+6*j)) ...  % same variable name
              & strcmp(typs(j(1)),   typs(j)) ...  % same type  
              &       (accs(j(1)) == accs(j));     % same access
      ninds = ninds + 1;
      indtyps{ninds} = typs{j(1)};
      inddims{ninds} = dims{j(1)};
      indaccs(ninds) = accs(j(1));
      inds(j(find(match))) = ninds;
      invinds(ninds) = j(1);
      j = j(find(~match));            % find remaining indirect arguments
    end

%
% output various diagnostics
%

    disp(['    local constants:    ' num2str(find(ptrs==OP_GBL & accs==OP_READ)-1) ]);
    disp(['    global reductions:  ' num2str(find(ptrs==OP_GBL & accs~=OP_READ)-1) ]);
    disp(['    direct arguments:   ' num2str(find(ptrs==OP_ID)-1) ]);
    disp(['    indirect arguments: ' num2str(find(ptrs==OP_PTR)-1) ]);
    if (ninds>0)
      disp(['    number of indirect datasets: ' num2str(ninds) ]);
    end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  create new kernel file, starting with CUDA kernel function
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if (target==OP_CUDA)
      file = strvcat('// user function         ',' ',...
                     '__device__               ',...
                    ['#include "' fn_name '.h"'],' ',' ',...
                     '// CUDA kernel function',' ',...
                    ['__global__ void op_cuda_' fn_name '(']);

    elseif (target==OP_x86)
      file = strvcat('// user function         ',' ',...
                    ['#include "' fn_name '.h"'],' ',' ',...
                     '// x86 kernel function',' ',...
                    ['void op_x86_' fn_name '(']);
      if (ninds>0)
        file = strvcat(file,'  int    blockIdx,');
      end
    end

    for m = 1:ninds
      line = '  INDTYP *ind_ARG, int *ind_ARG_ptrs, int *ind_ARG_sizes, int *ind_ARG_offset,';
      file = strvcat(file,rep(line,m));
    end

    for m = 1:nargs
      if (ptrs(m)==OP_GBL & accs(m)==OP_READ)
        line = '  const TYP *ARG,';             % constants declared const for performance
      elseif (ptrs(m)==OP_ID & ninds>0)
        line = '  TYP *ARG_d,';
      elseif (ptrs(m)==OP_GBL | ptrs(m)==OP_ID)
        line = '  TYP *ARG,';
      else
        line = '  int   *ARG_ptrs,';
      end
      file = strvcat(file,rep(line,m));
    end

    if (ninds>0)
      file = strvcat(file,'  int    block_offset,',...
                          '  int   *blkmap,      ',...
                          '  int   *offset,      ',...
                          '  int   *nelems,      ',...
                          '  int   *ncolors,     ',...
                          '  int   *colors) {    ',' ');
    else
      if (target==OP_CUDA)
        file = strvcat(file,'  int   set_size ) {',' ');
      elseif (target==OP_x86)
        file = strvcat(file,'  int   begin,    ',...
                            '  int   finish ) {',' ');
      end
    end

    if (target==OP_CUDA)
      for m = 1:nargs
        if (ptrs(m)==OP_GBL & accs(m)~=OP_READ)
          line = '  TYP ARG_l[DIM];';
          file = strvcat(file,rep(line,m));
          if (accs(m)==OP_INC)
            line = '  for (int d=0; d<DIM; d++) ARG_l[d]=ZERO_TYP;';
          else
            line = '  for (int d=0; d<DIM; d++) ARG_l[d]=ARG[d];';
          end
          file = strvcat(file,rep(line,m));
        else
          if (ptrs(m)==OP_PTR & accs(m)==OP_INC)
            line = '  TYP ARG_l[DIM];';
            file = strvcat(file,rep(line,m));
          end
        end
      end

    elseif (target==OP_x86)
      for m = 1:nargs
        if (ptrs(m)==OP_PTR & accs(m)==OP_INC)
          line = '  TYP ARG_l[DIM];';
          file = strvcat(file,rep(line,m));
        end
      end

    end

%
% lengthy code for general case with indirection
%
    if (ninds>0)
       file = strvcat(file,' ');
       for m = 1:ninds
        line = '  __shared__ int   *ind_ARG_ptr, ind_ARG_size;';
        file = strvcat(file,rep(line,m));
      end
      for m = 1:ninds
        line = '  __shared__ INDTYP *ind_ARG_s;';
        file = strvcat(file,rep(line,m));
      end

      for m = 1:nargs
        if (ptrs(m)==OP_ID)
          line = '  __shared__ TYP *ARG;';
          file = strvcat(file,rep(line,m));
        elseif (ptrs(m)==OP_PTR)
          line = '  __shared__ int   *ARG_ptr;';
          file = strvcat(file,rep(line,m));
        end
      end

      if (ind_inc) 
        file = strvcat(file,...
           '  __shared__ int    nelems2, ncolor, *color;');
      end

      if (target==OP_CUDA)
        file = strvcat(file,...
             '  __shared__ int    blockId, nelem;',' ',...
             '  extern __shared__ char shared[];',' ',...
             '  if (threadIdx.x==0) {',' ',...
             '    // get sizes and shift pointers and direct-mapped data',' ',...
             '    blockId = blkmap[blockIdx.x + block_offset];',...
             '    nelem   = nelems[blockId];',' ');
      elseif (target==OP_x86)
        file = strvcat(file,...
             '  __shared__ int    blockId, nelem;',' ',...
             '  __shared__ char shared[64000];',' ',...
             '  if (0==0) {',' ',...
             '    // get sizes and shift pointers and direct-mapped data',' ',...
             '    blockId = blkmap[blockIdx + block_offset];',...
             '    nelem   = nelems[blockId];',' ');
      end

      if (ind_inc) 
        if (target==OP_CUDA)
        file = strvcat(file,...
           '    nelems2 = blockDim.x*(1+(nelem-1)/blockDim.x);',...
           '    ncolor  = ncolors[blockId];',...
           '    color   = colors + offset[blockId];',' ');
        elseif (target==OP_x86)
        file = strvcat(file,...
           '    nelems2 = nelem;',...
           '    ncolor  = ncolors[blockId];',...
           '    color   = colors + offset[blockId];',' ');
        end
      end

      for m = 1:ninds
        line = '    ind_ARG_size = ind_ARG_sizes[blockId];';
        file = strvcat(file,rep(line,m));
      end
      file = strvcat(file,' ');
      for m = 1:ninds
        line = '    ind_ARG_ptr = ind_ARG_ptrs + ind_ARG_offset[blockId];';
        file = strvcat(file,rep(line,m));
      end
      file = strvcat(file,' ');
      for m = 1:nargs
        if (ptrs(m)==OP_ID)
          line = '    ARG         = ARG_d    + offset[blockId]*DIM;';
          file = strvcat(file,rep(line,m));
        elseif(ptrs(m)==OP_PTR)
          line = '    ARG_ptr     = ARG_ptrs + offset[blockId];';
          file = strvcat(file,rep(line,m));
        end
      end

      file = strvcat(file,' ','    // set shared memory pointers',' ',...
                              '    int nbytes = 0;');
      for m = 1:ninds
         line = '    ind_ARG_s = (INDTYP *) &shared[nbytes];';
         file = strvcat(file,rep(line,m));
         if (m<ninds)
           line = '    nbytes    += ROUND_UP(ind_ARG_size*sizeof(INDTYP)*INDDIM);';
           file = strvcat(file,rep(line,m));
         end
      end

      file = strvcat(file,'  }',' ','  __syncthreads(); // make sure all of above completed',' ',...
                          '  // copy indirect datasets into shared memory or zero increment',' ');
      for m = 1:ninds
        if(indaccs(m)==OP_READ | indaccs(m)==OP_RW | indaccs(m)==OP_INC)
          if (target==OP_CUDA)
            line = '  for (int n=threadIdx.x; n<INDARG_size; n+=blockDim.x)';
          elseif (target==OP_x86)
            line = '  for (int n=0; n<INDARG_size; n++)';
          end
          file = strvcat(file,rep(line,m));
          line = '    for (int d=0; d<INDDIM; d++)';
          file = strvcat(file,rep(line,m));
        end
        if(indaccs(m)==OP_READ | indaccs(m)==OP_RW)
          line = '      INDARG_s[d+n*INDDIM] = INDARG[d+INDARG_ptr[n]*INDDIM];';
        elseif(indaccs(m)==OP_INC)
          line = '      INDARG_s[d+n*INDDIM] = ZERO_INDTYP;';
        end
        file = strvcat(file,rep(line,m),' ');
      end

      file = strvcat(file,'  __syncthreads();',' ',...
                          '  // process set elements',' ');

      if (ind_inc)
        if (target==OP_CUDA)
	  file = strvcat(file,'  for (int n=threadIdx.x; n<nelems2; n+=blockDim.x) {');
        elseif (target==OP_x86)
          file = strvcat(file,'  for (int n=0; n<nelems2; n++) {');
        end
        file = strvcat(file,'    int col2 = -1;                             ',' ',...
                            '    if (n<nelem) {                             ',' ',...
                            '      // initialise local variables            ',' ');

        for m = 1:nargs
          if (ptrs(m)==OP_PTR & accs(m)==OP_INC)
            line = '      for (int d=0; d<DIM; d++)';
            file = strvcat(file,rep(line,m));
            line = '        ARG_l[d] = ZERO_TYP;';
            file = strvcat(file,rep(line,m));
          end
        end

      else
        if (target==OP_CUDA)
          file = strvcat(file,'  for (int n=threadIdx.x; n<nelem; n+=blockDim.x) {');
        elseif (target==OP_x86)
          file = strvcat(file,'  for (int n=0; n<nelem; n++) {');
        end
      end

%
% simple alternative when no indirection
%
    else

      if (target==OP_CUDA)
        file = strvcat(file,' ','  // process set elements',' ', ...
                                '  for (int n=threadIdx.x+blockIdx.x*blockDim.x;', ...
                                '       n<set_size; n+=blockDim.x*gridDim.x) {');
      elseif (target==OP_x86)
        file = strvcat(file,' ','  // process set elements',' ', ...
                                '  for (int n=begin; n<finish; n++) {');
      end
    end

%
% kernel call
%

    file = strvcat(file,' ','      // user-supplied kernel call',' ');

    for m = 1:nargs
      line = ['      ' fn_name '( '];
      if (m~=1)
        line = blanks(length(line));
      end
      if (ptrs(m)==OP_GBL)
        if (accs(m)==OP_READ || target==OP_x86 )
          line = [ line 'ARG,' ];
        else
          line = [ line 'ARG_l,' ];
        end
      elseif (ptrs(m)==OP_PTR & accs(m)==OP_INC)
        line = [ line 'ARG_l,' ];
      elseif (ptrs(m)==OP_PTR)
        line = [ line sprintf('ind_arg%d_s+ARG_ptr[n]*DIM,',inds(m)-1) ];
      elseif (ptrs(m)==OP_ID)
        line = [ line 'ARG+n*DIM,' ];
      else
        error('internal error 1')
      end
      if (m==nargs)
        line = [ line(1:end-1) ' );' ];
      end

      file = strvcat(file,rep(line,m));
    end

%
% updating for indirect kernels ...
%

    if(ninds>0)
      if(ind_inc)
        file = strvcat(file,' ','      col2 = color[n];                  ',...
                                '    }                                   ',' ',...
                                '    // store local variables            ',' ',...
                                '    for (int col=0; col<ncolor; col++) {',...
                                '      if (col2==col) {                  ');
        for m = 1:nargs
          if (ptrs(m)==OP_PTR & accs(m)==OP_INC)
            line = '        for (int d=0; d<DIM; d++)';
            file = strvcat(file,rep(line,m));
            line = sprintf('          ind_arg%d_s[d+ARG_ptr[n]*DIM] += ARG_l[d];',inds(m)-1);
            file = strvcat(file,rep(line,m));
          end
        end
        file = strvcat(file,'      }','      __syncthreads();','    }',' ');
      end

      file = strvcat(file,'  }',' ');
      if(max(indaccs(1:ninds)~=OP_READ)>0)
        file = strvcat(file,'  // apply pointered write/increment',' ');
      end
      for m = 1:ninds
        if(indaccs(m)==OP_WRITE | indaccs(m)==OP_RW | indaccs(m)==OP_INC)
          if (target==OP_CUDA)
            line = '  for (int n=threadIdx.x; n<INDARG_size; n+=blockDim.x)';
          elseif (target==OP_x86)
            line = '  for (int n=0; n<INDARG_size; n++)';
          end
          file = strvcat(file,rep(line,m));
          line = '    for (int d=0; d<INDDIM; d++)';
          file = strvcat(file,rep(line,m));
        end
        if(indaccs(m)==OP_WRITE | indaccs(m)==OP_RW)
          line = '      INDARG[d+INDARG_ptr[n]*INDDIM] = INDARG_s[d+n*INDDIM];';
          file = strvcat(file,rep(line,m),' ');
        elseif(indaccs(m)==OP_INC)
          line = '      INDARG[d+INDARG_ptr[n]*INDDIM] += INDARG_s[d+n*INDDIM];';
          file = strvcat(file,rep(line,m),' ');
        end
      end
%
% ... and direct kernels
%
    else
      file = strvcat(file,'  }');
    end

%
% global reduction
%
    if (target==OP_CUDA & reduct)
      file = strvcat(file,' ','  // global reductions',' ');
      for m = 1:nargs
        if (ptrs(m)==OP_GBL & accs(m)~=OP_READ)
          if(accs(m)==OP_INC)
            line = '  for(int d=0; d<DIM; d++) op_reduction<OP_INC>(&ARG[d],ARG_l[d]);';
          elseif (accs(m)==OP_MIN)
            line = '  for(int d=0; d<DIM; d++) op_reduction<OP_MIN>(&ARG[d],ARG_l[d]);';
          elseif (accs(m)==OP_MAX)
            line = '  for(int d=0; d<DIM; d++) op_reduction<OP_MAX>(&ARG[d],ARG_l[d]);';
          else
            error('internal error: invalid reduction option')
          end
          file = strvcat(file,rep(line,m));
        end
      end
    end

    file = strvcat(file,'}');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% then C++ stub function
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    file = strvcat(file,' ',' ','// host stub function            ',' ',...
                       ['void op_par_loop_' fn_name '(char const *name, op_set set,']);

    for m = 1:nargs
      if(ptrs(m)==OP_GBL)
        line = ['  TYP *arg%dh,int idx%d, op_ptr ptr%d, int dim%d,' ...
                ' char const *typ%d, op_access acc%d'];
      else
        line = ['  op_dat arg%d, int idx%d, op_ptr ptr%d, int dim%d,' ...
                ' char const *typ%d, op_access acc%d'];
      end
      line = rep(sprintf(line, m-1,m-1,m-1,m-1,m-1,m-1),m);

      if (m<nargs)
        file = strvcat(file,[line ',']);
      else
        file = strvcat(file,[line '){'],' ');
      end
    end

    for m = 1:nargs
      if (ptrs(m)==OP_GBL)
        line = '  op_dat ARG = {{0,0,"null"},0,0,0,(char *)ARGh,NULL,"TYP","gbl"};';
        file = strvcat(file,rep(line,m));
      end
    end

%
%   indirect bits
%
    if (ninds>0)
      file = strvcat(file,' ',...
             sprintf('  int         nargs = %d, ninds = %d;',nargs,ninds),' ');

      for l=1:6
        if (l==1)
          word = 'arg';
          line = sprintf('  op_dat      args[%d] = {',nargs);
        elseif (l==2)
          word = 'idx';
          line = sprintf('  int         idxs[%d] = {',nargs);
        elseif (l==3)
          word = 'ptr';
          line = sprintf('  op_ptr      ptrs[%d] = {',nargs);
        elseif (l==4)
          word = 'dim';
          line = sprintf('  int         dims[%d] = {',nargs);
        elseif (l==5)
          word = 'typ';
          line = sprintf('  char const *typs[%d] = {',nargs);
        elseif (l==6)
          word = 'acc';
          line = sprintf('  op_access   accs[%d] = {',nargs);
        end

        for m = 1:nargs
          if (m<nargs)
            line = strcat(line,word,num2str(m-1),', ');
          else
            line = strcat(line,word,num2str(m-1),'};');
          end
        end
        file = strvcat(file,line);
      end

      line = sprintf('  int         inds[%d] = {',nargs);
      for m = 1:nargs
        if (m<nargs)
          line = strcat(line,num2str(inds(m)-1),', ');
        else
          line = strcat(line,num2str(inds(m)-1),'};');
        end
      end
      file = strvcat(file,line);

      file = strvcat(file,' ',...
       '  if (OP_diags>2) {              ',...
      ['    printf(" kernel routine with indirection: ' fn_name ' \n");'],...
       '  }                              ');

%
% direct bit
%
    else
      file = strvcat(file,' ',...
       '  if (OP_diags>2) {              ',...
      ['    printf(" kernel routine w/o indirection:  ' fn_name ' \n");'],...
       '  }                              ');
    end

%
% start timing
%
    file = strvcat(file,' ','  // initialise timers                    ',...
                        ' ','  double cpu_t1, cpu_t2, wall_t1, wall_t2;',...
                            '  timers(&cpu_t1, &wall_t1);              ');

%
% set number of threads in x86 execution and create arrays for reduction
%
    if (target==OP_x86)
      file = strvcat(file,' ','  // set number of threads',' ',...
                   '#ifdef _OPENMP                          ',...
                   '  int nthreads = omp_get_max_threads( );',...
                   '#else                                   ',...
                   '  int nthreads = 1;                     ',...
                   '#endif                                  ');

      if (reduct)
	file = strvcat(file,' ',...
             '  // allocate and initialise arrays for global reduction');
        for m = 1:nargs
          if (ptrs(m)==OP_GBL & accs(m)~=OP_READ)
            line = '  TYP ARG_l[DIM+64*64];';
            file = strvcat(file,' ',rep(line,m),...
                           '  for (int thr=0; thr<nthreads; thr++)');
            if (accs(m)==OP_INC)
              line = '    for (int d=0; d<DIM; d++) ARG_l[d+thr*64]=ZERO_TYP;';
            else
              line = '    for (int d=0; d<DIM; d++) ARG_l[d+thr*64]=ARGh[d];';
            end
            file = strvcat(file,rep(line,m));
          end
        end
      end
    end
%
% transfer constants
%
    if (target==OP_CUDA)

    if (length(find(ptrs(1:nargs)==OP_GBL & accs(1:nargs)==OP_READ))>0)
      file = strvcat(file,'  ',...
       '  // transfer constants to GPU',' ',...
       '  int consts_bytes = 0;');
      for m=1:nargs
        if(ptrs(m)==OP_GBL & accs(m)==OP_READ);
          line = '  consts_bytes += ROUND_UP(DIM*sizeof(TYP));';
          file = strvcat(file,rep(line,m));
        end
      end

      file = strvcat(file,'  ',...
       '  reallocConstArrays(consts_bytes);',' ',...
       '  consts_bytes = 0;');

      for m=1:nargs
        if(ptrs(m)==OP_GBL & accs(m)==OP_READ);
          line = '  ARG.dat   = OP_consts_h + consts_bytes;';
          file = strvcat(file,rep(line,m));
          line = '  ARG.dat_d = OP_consts_d + consts_bytes;';
          file = strvcat(file,rep(line,m));
          line = '  for (int d=0; d<DIM; d++) ((TYP *)ARG.dat)[d] = ((TYP *)ARGh)[d];';
          file = strvcat(file,rep(line,m));
          line = '  consts_bytes += ROUND_UP(DIM*sizeof(TYP));';
          file = strvcat(file,rep(line,m));
        end
      end

      file = strvcat(file,'  ','  mvConstArraysToDevice(consts_bytes);');
    end

    end

%
% transfer global reduction initial data
%
    if (target==OP_CUDA)

    if (reduct)
      file = strvcat(file,'  ',...
       '  // transfer global reduction data to GPU',' ',...
       '  int reduct_bytes = 0;',...
       '  int reduct_size  = 0;');

      for m=1:nargs
        if(ptrs(m)==OP_GBL & accs(m)~=OP_READ);
          line = '  reduct_bytes += ROUND_UP(DIM*sizeof(TYP));';
          file = strvcat(file,rep(line,m));
          line = '  reduct_size   = MAX(reduct_size,sizeof(TYP));';
          file = strvcat(file,rep(line,m));
        end
      end

      file = strvcat(file,'  ',...
       '  reallocReductArrays(reduct_bytes);',' ',...
       '  reduct_bytes = 0;');

      for m=1:nargs
        if(ptrs(m)==OP_GBL & accs(m)~=OP_READ);
          line = '  ARG.dat   = OP_reduct_h + reduct_bytes;';
          file = strvcat(file,rep(line,m));
          line = '  ARG.dat_d = OP_reduct_d + reduct_bytes;';
          file = strvcat(file,rep(line,m));
          line = '  for (int d=0; d<DIM; d++) ((TYP *)ARG.dat)[d] = ARGh[d];';
          file = strvcat(file,rep(line,m));
          line = '  reduct_bytes += ROUND_UP(DIM*sizeof(TYP));';
          file = strvcat(file,rep(line,m));
        end
      end

      file = strvcat(file,'  ','  mvReductArraysToDevice(reduct_bytes);');
    end

    end

%
% kernel call for indirect version
%
    if (ninds>0)

      if (target==OP_CUDA)
       file = strvcat(file,' ',...
        '  // get plan                    ',' ',...
        '  op_plan *Plan = plan(name,set,nargs,args,idxs,ptrs,dims,typs,accs,ninds,inds);',' ',...
        '  // execute plan                ',' ',...
        '  int block_offset = 0;          ',' ',...
        '  for (int col=0; col<(*Plan).ncolors; col++) { ',' ',...
        '    int nblocks = (*Plan).ncolblk[col];         ',...
        '    int nthread = OP_block_size;                ');

       if (reduct)
 	file = strvcat(file,'    int nshared = MAX((*Plan).nshared,reduct_size*nthread/2);');
       else
 	file = strvcat(file,'    int nshared = (*Plan).nshared;');
       end

       file = strvcat(file,['    op_cuda_' fn_name '<<<nblocks,nthread,nshared>>>(']);

       for m = 1:ninds
         line = [ '       (TYP *)ARG.dat_d, ' ...
          sprintf('(*Plan).ind_ptrs[%d], (*Plan).ind_sizes[%d], (*Plan).ind_offs[%d],',m-1,m-1,m-1) ];
         file = strvcat(file,rep(line,invinds(m)));
       end

       for m = 1:nargs
         if (inds(m)==0)
           line = '       (TYP *)ARG.dat_d,';
         else
           line = sprintf('       (*Plan).ptrs[%d],',m-1);
         end
         file = strvcat(file,rep(line,m));
       end

       file = strvcat(file, ... 
         '       block_offset,                                       ', ...
         '       (*Plan).blkmap,                                     ', ...
         '       (*Plan).offset,                                     ', ...
         '       (*Plan).nelems,                                     ', ...
         '       (*Plan).nthrcol,                                    ', ...
         '       (*Plan).thrcol);                                    ',' ', ...
         '    cutilSafeCall(cudaThreadSynchronize());                 ', ...
        ['    cutilCheckMsg("op_cuda_' fn_name ' execution failed\n");'],' ', ...
         '    block_offset += nblocks;                                ', ...
         '  }                                                         ');

      elseif (target==OP_x86)
       file = strvcat(file,' ',...
        '  // get plan                    ',' ',...
        '  op_plan *Plan = plan(name,set,nargs,args,idxs,ptrs,dims,typs,accs,ninds,inds);',' ',...
        '  // execute plan                ',' ',...
        '  int block_offset = 0;          ',' ',...
        '  for (int col=0; col<(*Plan).ncolors; col++) { ',...
        '    int nblocks = (*Plan).ncolblk[col];         ',' ',...
        '#pragma omp parallel for',...
        '    for (int blockIdx=0; blockIdx<nblocks; blockIdx++)');

       file = strvcat(file,['     op_x86_' fn_name '( blockIdx,']);

       for m = 1:ninds
         line = [ '       (TYP *)ARG.dat, ' ...
          sprintf('(*Plan).ind_ptrs[%d], (*Plan).ind_sizes[%d], (*Plan).ind_offs[%d],',m-1,m-1,m-1) ];
         file = strvcat(file,rep(line,invinds(m)));
       end

       for m = 1:nargs
         if (inds(m)==0)
           line = '       (TYP *)ARG.dat,';
         else
           line = sprintf('       (*Plan).ptrs[%d],',m-1);
         end
         file = strvcat(file,rep(line,m));
       end

       file = strvcat(file, ... 
         '       block_offset,                                       ', ...
         '       (*Plan).blkmap,                                     ', ...
         '       (*Plan).offset,                                     ', ...
         '       (*Plan).nelems,                                     ', ...
         '       (*Plan).nthrcol,                                    ', ...
         '       (*Plan).thrcol);                                    ',' ', ...
         '    block_offset += nblocks;                                ', ...
         '  }                                                         ');
      end
%
% kernel call for direct version
%
    else

      file = strvcat(file,' ','  // execute plan             ',' ',...
                              '  int nblocks = 100;          ',...
                              '  int nthread = OP_block_size;');

      if (target==OP_CUDA)
        if (reduct)
          file = strvcat(file,'  int nshared = reduct_size*nthread/2;',' ');
          line = ['  op_cuda_' fn_name '<<<nblocks,nthread,nshared>>>( '];
        else
          line = ['  op_cuda_' fn_name '<<<nblocks,nthread>>>( '];
        end

        for m = 1:nargs
          file = strvcat(file,rep([line '(TYP *) ARG.dat_d,'],m));
          line = blanks(length(line));
        end

        file = strvcat(file,[ line 'set.size );'],' ',... 
          '  cutilSafeCall(cudaThreadSynchronize());                  ', ...
         ['  cutilCheckMsg("op_cuda_', fn_name ' execution failed\n");']);

      elseif (target==OP_x86)
        file = strvcat(file,'#pragma omp parallel for                     ',...
                            '  for (int thr=0; thr<nthreads; thr++) {         ',...
                            '    int start  = (set.size* thr   )/nthreads;', ...
                            '    int finish = (set.size*(thr+1))/nthreads;');
        line = ['    op_x86_' fn_name '( '];

        for m = 1:nargs
          if(ptrs(m)==OP_GBL & accs(m)~=OP_READ);
            file = strvcat(file,rep([line 'ARG_l + thr*64,'],m));
          else
            file = strvcat(file,rep([line '(TYP *) ARG.dat,'],m));
          end
          line = blanks(length(line));
        end

        file = strvcat(file,[ line 'start, finish );'],'  }');
      end
    end

%
% transfer global reduction initial data
%
    if (target==OP_CUDA && reduct)
      file = strvcat(file,' ','  // transfer global reduction data back to CPU',...
                          ' ','  mvReductArraysToHost(reduct_bytes);',' ');
      for m=1:nargs
        if(ptrs(m)==OP_GBL & accs(m)~=OP_READ);
          line = '  for (int d=0; d<DIM; d++) ARGh[d] = ((TYP *)ARG.dat)[d];';
          file = strvcat(file,rep(line,m));
        end
      end
    end

%
% combine reduction data from multiple OpenMP threads
%
    if (target==OP_x86 && reduct)
        file = strvcat(file,' ','  // combine reduction data');
      for m=1:nargs
        if(ptrs(m)==OP_GBL & accs(m)~=OP_READ);
          file = strvcat(file,' ','  for (int thr=0; thr<nthreads; thr++)');
          if(accs(m)==OP_INC)
            line = '    for(int d=0; d<DIM; d++) ARGh[d] += ARG_l[d+thr*64];';
          elseif (accs(m)==OP_MIN)
            line = '    for(int d=0; d<DIM; d++) ARGh[d]  = MIN(ARGh[d],ARG_l[d+thr*64]);';
          elseif (accs(m)==OP_MAX)
            line = '    for(int d=0; d<DIM; d++) ARGh[d]  = MAX(ARGh[d],ARG_l[d+thr*64]);';
          else
            error('internal error: invalid reduction option')
          end
          file = strvcat(file,rep(line,m));
        end
      end
    end

%
% update kernel record
%

  file = strvcat(file,' ','  // update kernel record',' ',...
           '  timers(&cpu_t2, &wall_t2);                                  ',...
          ['  OP_kernels[' num2str(nker) '].name      = name;             '],...
          ['  OP_kernels[' num2str(nker) '].count    += 1;                '],...
          ['  OP_kernels[' num2str(nker) '].time     += wall_t2 - wall_t1;']);
  if (ninds>0)
    file = strvcat(file,...
          ['  OP_kernels[' num2str(nker) '].transfer += (*Plan).transfer;']);
  else

    line = ['  OP_kernels[' num2str(nker) '].transfer += (float)set.size * '];

    for m = 1:nargs
      if(ptrs(m)~=OP_GBL)
        if (accs(m)==OP_READ)
          file = strvcat(file,rep([line 'ARG.size;'],m));
        else
          file = strvcat(file,rep([line 'ARG.size * 2.0f;'],m));
        end
      end
    end
  end

  file = strvcat(file,'} ',' ');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  output individual kernel file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if (target==OP_CUDA)
      fid = fopen(strcat(fn_name,'_kernel.cu'),'wt');
    elseif (target==OP_x86) 
      fid = fopen(strcat(fn_name,'_kernel.cpp'),'wt');
    end

    fprintf(fid,'// \n// auto-generated by op2.m on %s \n//\n\n',date);
    for n=1:size(file,1)
      line = file(n,:);
      if (target==OP_x86)
        line = regexprep(line,'__shared__ ','');
      end
      fprintf(fid,'%s\n',line);
    end
    fclose(fid);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  append kernel bits for new source file and master kernel file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    old = [ 'op_par_loop_' num2str(nargs) '(' fn_name ','];
    new = [ 'op_par_loop_' fn_name '('];
    new_file = regexprep(new_file,old,new);

    if (nkernels==1)
      new_file2 = ' ';
    end

    new_file2 = strvcat(new_file2,...
    ['void op_par_loop_' fn_name '(char const *, op_set,   ']);

    for n = 1:nargs
      if (ptrs(n)==OP_GBL)
        line = [ '  ' typs{n} '*, int, op_ptr, int, char const *, op_access' ];
      else
        line = '  op_dat, int, op_ptr, int, char const *, op_access';
      end
      if (n==nargs)
        new_file2 = strvcat(new_file2,[line ');'],' ');
      else
        new_file2 = strvcat(new_file2,[line ',']);
      end
    end

    if (nkernels==1 & narg==1)
      ker_file3 = ' ';
    end

    if (target==OP_CUDA)
      ker_file3 = strvcat(ker_file3, ['#include "' fn_name '_kernel.cu"']);
    elseif (target==OP_x86)
      ker_file3 = strvcat(ker_file3, ['#include "' fn_name '_kernel.cpp"']);
    end
  end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  output new source file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  new_file2 = strvcat('#include "op_datatypes.h"',' ',...
                      '//',... 
                      '// op_par_loop declarations',... 
                      '//',... 
                      new_file2);

  loc = strfind(new_file,'#include "op_seq.h"');

  if (target==1)
    fid = fopen(strcat(filename,'_op.cpp'),'wt');
    fprintf(fid,'// \n// auto-generated by op2.m on %s \n//\n\n',date);
    fprintf(fid,'%s',new_file(1:loc-1));

    for n=1:size(new_file2,1)
      fprintf(fid,'%s\n',new_file2(n,:));
    end

    fprintf(fid,'%s',new_file(loc+20:end));

    fclose(fid);
  end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  process global constants for master kernel file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  if(narg==1)
    ker_file1 = '';
    ker_file2 = '';
  end

  src_file = fileread([filename '.cpp']);
  src_file = regexprep(src_file,'\s','');

  while (~isempty(strfind(src_file,'op_decl_const(')))
    loc  = min(strfind(src_file,'op_decl_const('));
    src_file = src_file(loc+14:end);
    [src_args, src_file] = strtok(src_file,')');

    loc = [0 strfind(src_args,',') length(src_args)+1];
    na  = length(loc)-1;

    if( na ~= 4)
      error(sprintf('wrong number of arguments in op_decl_const'));
    end

    for n = 1:na
      C{n} = src_args(loc(n)+1:loc(n+1)-1);
    end

    name = C{4}(2:end-1);
    type = C{2}(2:end-1);
    [dim,ok] = str2num(C{1});

    if (target==OP_CUDA)

    if (ok & dim==1)
      ker_file1 = strvcat(ker_file1,[ '__constant__ ' type ' ' name ';' ]);
    elseif (ok)
      ker_file1 = strvcat(ker_file1,[ '__constant__ ' type ' ' name '[' C{1} '];' ]);
    else
      ker_file1 = strvcat(ker_file1,[ '__constant__ ' type ' ' name '[MAX_CONST_SIZE];' ]);
      ker_file2 = strvcat(ker_file2,['  if(~strcmp(name,"' name '") && size>MAX_CONST_SIZE) {'],...
                ['    printf("error: MAX_CONST_SIZE not big enough\n"); exit(1);'],...
                 '  }');

%      ker_file1 = strvcat(ker_file1,['__device__ ' type ' *' name ';']);
%      ker_file2 = strvcat(ker_file2,['  if(~strcmp(name,"' name '")) {'],...
%                ['    cutilSafeCall(cudaMalloc((void **)&' name ', dim*size));'],...
%                 '  }');
    end

    elseif (target==OP_x86)

    if (ok & dim==1)
      ker_file1 = strvcat(ker_file1,[ 'extern ' type ' ' name ';' ]);
    else
      ker_file1 = strvcat(ker_file1,[ 'extern ' type ' ' name '[' C{1} '];' ]);
    end

    end

    disp(sprintf('\n  global constant (%s) of size %s',name,C{1}));
  end

end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%  output one master kernel file
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if (target==OP_CUDA)
  file = strvcat(...
  '// header                 ',' ',...
  '#include "op_lib.cu"      ',' ',...
  '// global constants       ',' ',...
  '#ifndef MAX_CONST_SIZE    ',...
  '#define MAX_CONST_SIZE 128',...
  '#endif                    ',' ',...
  ker_file1,...
  ' ',...
  'void op_decl_const_char(int dim, char const *type, int size, char *dat, char const *name){',...
  ker_file2,...
  '  cutilSafeCall(cudaMemcpyToSymbol(name, dat, dim*size));',....
  '} ',' ',...
  '// user kernel files',...
  ker_file3);

  fid = fopen([ varargin{1} '_kernels.cu'],'wt');

elseif (target==OP_x86) 
  file = strvcat(...
  '// header                 ',' ',...
  '#include "op_lib.cpp"      ',' ',...
  '// global constants       ',' ',...
  ker_file1,' ',...
  '// user kernel files',...
  ker_file3);

  fid = fopen([ varargin{1} '_kernels.cpp'],'wt');
end

fprintf(fid,'// \n// auto-generated by op2.m on %s \n//\n\n',date);

for n=1:size(file,1)
  fprintf(fid,'%s\n',file(n,:));
end
fclose(fid);

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% a little function to replace keywords
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function line = rep(line,m)

global dims idxs typs indtyps inddims
global OP_typs_labels OP_typs_CPP

line = regexprep(line,'INDDIM',inddims(m));
line = regexprep(line,'INDARG',sprintf('ind_arg%d',m-1));
line = regexprep(line,'INDTYP',indtyps(m));

line = regexprep(line,'DIM',dims(m));
line = regexprep(line,'ARG',sprintf('arg%d',m-1));
line = regexprep(line,'TYP',typs(m));
line = regexprep(line,'IDX',num2str(idxs(m)));
