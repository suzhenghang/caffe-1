#include <math_functions.h>  // CUDA's, not caffe's, for fabs, signbit
#include <thrust/device_vector.h>
#include <thrust/functional.h>  // thrust::plus
#include <thrust/reduce.h>

#include <cmath>

#include "caffe/common.hpp"
#include "caffe/util/math_functions.hpp"

namespace caffe {

template <>
void caffe_gpu_gemm<float>(const CBLAS_TRANSPOSE TransA,
    const CBLAS_TRANSPOSE TransB, const int M, const int N, const int K,
    const float alpha, const float* A, const float* B, const float beta,
    float* C) {
  // Note that cublas follows fortran order.
  int lda = (TransA == CblasNoTrans) ? K : M;
  int ldb = (TransB == CblasNoTrans) ? N : K;
  cublasOperation_t cuTransA =
      (TransA == CblasNoTrans) ? CUBLAS_OP_N : CUBLAS_OP_T;
  cublasOperation_t cuTransB =
      (TransB == CblasNoTrans) ? CUBLAS_OP_N : CUBLAS_OP_T;
  CUBLAS_CHECK(cublasSgemm(Caffe::cublas_handle(), cuTransB, cuTransA,
      N, M, K, &alpha, B, ldb, A, lda, &beta, C, N));
}

template <>
void caffe_gpu_gemm<double>(const CBLAS_TRANSPOSE TransA,
    const CBLAS_TRANSPOSE TransB, const int M, const int N, const int K,
    const double alpha, const double* A, const double* B, const double beta,
    double* C) {
  // Note that cublas follows fortran order.
  int lda = (TransA == CblasNoTrans) ? K : M;
  int ldb = (TransB == CblasNoTrans) ? N : K;
  cublasOperation_t cuTransA =
      (TransA == CblasNoTrans) ? CUBLAS_OP_N : CUBLAS_OP_T;
  cublasOperation_t cuTransB =
      (TransB == CblasNoTrans) ? CUBLAS_OP_N : CUBLAS_OP_T;
  CUBLAS_CHECK(cublasDgemm(Caffe::cublas_handle(), cuTransB, cuTransA,
      N, M, K, &alpha, B, ldb, A, lda, &beta, C, N));
}

template <>
void caffe_gpu_sparse_mmcsr<float>(const int M, const int N, const int K,
    const float alpha, const float* A,
    const int nnz, const float* B_nonzero_buf, const int* B_idx_pointer_buf, const int* B_nonzero_idx_buf,
    const float beta,float* C){
	// For cuSPARSE, dense matrix A & C is column major, so we can instead compute C'=B'*A'
	// A & C are intrinsically transposed since c/c++ array is row major

	// as sparse B is expressed in CSR format, and CSC of B'is the same with CSR of B
	// use cusparse<t>cscmm if available, if not, transpose B (transposing may not affect the performance as above reason)
	//NON-BLOCKING NON-BLOCKING NON-BLOCKING
	CUSPARSE_CHECK(cusparseScsrmm(Caffe::cusparse_handle(),CUSPARSE_OPERATION_TRANSPOSE,
			//N,M,K,nnz, &alpha,
			K,M,N,nnz, &alpha,
			Caffe::cusparse_matdescr(), B_nonzero_buf, B_idx_pointer_buf, B_nonzero_idx_buf,
			A,K,&beta,C,N
			));
}

template <>
void caffe_gpu_sparse_mmcsr<double>(const int M, const int N, const int K,
    const double alpha, const double* A,
    const int nnz, const double* B_nonzero_buf, const int* B_idx_pointer_buf, const int* B_nonzero_idx_buf,
    const double beta,double* C){
	//NON-BLOCKING NON-BLOCKING NON-BLOCKING
	CUSPARSE_CHECK(cusparseDcsrmm(Caffe::cusparse_handle(),CUSPARSE_OPERATION_TRANSPOSE,
				N,M,K,nnz, &alpha,
				Caffe::cusparse_matdescr(), B_nonzero_buf, B_idx_pointer_buf, B_nonzero_idx_buf,
				A,K,&beta,C,N
				));
}

template <>
void caffe_gpu_sparse_dense2csr<float>(const int M, const int N,
    const float* A, int* nnzPerRow,
    float* A_nonzero_buf, int* A_idx_pointer_buf, int* A_nonzero_idx_buf, int *nnz_total){
	//cusparse<t>nnz() NON-BLOCKING
	//int nnz_total = 0;
	CUSPARSE_CHECK(cusparseSnnz(Caffe::cusparse_handle(),
			CUSPARSE_DIRECTION_COLUMN,
			N,M,
			Caffe::cusparse_matdescr(),
			A,N,
			nnzPerRow,//per row for c style row-major matrix
			nnz_total
			));

	CUSPARSE_CHECK(cusparseSdense2csc(Caffe::cusparse_handle(),
			N,M,
			Caffe::cusparse_matdescr(),
			A,N,
			nnzPerRow,//per row for c style row-major matrix
			A_nonzero_buf,A_nonzero_idx_buf,A_idx_pointer_buf
			));
}

template <>
void caffe_gpu_sparse_dense2csr<double>(const int M, const int N,
    const double* A, int* nnzPerRow,
    double* A_nonzero_buf, int* A_idx_pointer_buf, int* A_nonzero_idx_buf,int *nnz_total){
	//cusparse<t>nnz() NON-BLOCKING
	//int nnz_total = 0;
	CUSPARSE_CHECK(cusparseDnnz(Caffe::cusparse_handle(),
			CUSPARSE_DIRECTION_COLUMN,
			N,M,
			Caffe::cusparse_matdescr(),
			A,N,
			nnzPerRow,//per row for c style row-major matrix
			nnz_total
			));

	CUSPARSE_CHECK(cusparseDdense2csc(Caffe::cusparse_handle(),
			N,M,
			Caffe::cusparse_matdescr(),
			A,N,
			nnzPerRow,//per row for c style row-major matrix
			A_nonzero_buf,A_nonzero_idx_buf,A_idx_pointer_buf
			));
}

template <>
void caffe_gpu_gemv<float>(const CBLAS_TRANSPOSE TransA, const int M,
    const int N, const float alpha, const float* A, const float* x,
    const float beta, float* y) {
  cublasOperation_t cuTransA =
      (TransA == CblasNoTrans) ? CUBLAS_OP_T : CUBLAS_OP_N;
  CUBLAS_CHECK(cublasSgemv(Caffe::cublas_handle(), cuTransA, N, M, &alpha,
      A, N, x, 1, &beta, y, 1));
}

template <>
void caffe_gpu_gemv<double>(const CBLAS_TRANSPOSE TransA, const int M,
    const int N, const double alpha, const double* A, const double* x,
    const double beta, double* y) {
  cublasOperation_t cuTransA =
      (TransA == CblasNoTrans) ? CUBLAS_OP_T : CUBLAS_OP_N;
  CUBLAS_CHECK(cublasDgemv(Caffe::cublas_handle(), cuTransA, N, M, &alpha,
      A, N, x, 1, &beta, y, 1));
}

template <>
void caffe_gpu_axpy<float>(const int N, const float alpha, const float* X,
    float* Y) {
  CUBLAS_CHECK(cublasSaxpy(Caffe::cublas_handle(), N, &alpha, X, 1, Y, 1));
}

template <>
void caffe_gpu_axpy<double>(const int N, const double alpha, const double* X,
    double* Y) {
  CUBLAS_CHECK(cublasDaxpy(Caffe::cublas_handle(), N, &alpha, X, 1, Y, 1));
}




template  <typename Dtype>
__global__ void zerout_kernel(void * mutable_gpu_data, int count, Dtype thre){
	//Dtype thre = Dtype(th);
	Dtype* data_ptr_tmp =  static_cast<Dtype*>(mutable_gpu_data);
		//  for(int i=0;i<count;i++){
		//	  if(data_ptr_tmp[i]<thre && data_ptr_tmp[i]>(-thre)){
		//		  data_ptr_tmp[i]=0;
		//	  }
		//  }
	int tid = threadIdx.x + blockDim.x*blockIdx.x;
	while(tid<count){
		if(data_ptr_tmp[tid]<thre && data_ptr_tmp[tid]>(-thre)){
			data_ptr_tmp[tid] = 0;
		}
		tid += gridDim.x*blockDim.x;
	}
}

template <typename Dtype>
void caffe_gpu_zerout(void * mutable_gpu_data, const int count, Dtype th){
	zerout_kernel<<<CAFFE_GET_BLOCKS(count), CAFFE_CUDA_NUM_THREADS>>>(mutable_gpu_data,  count,  th);
}

template void caffe_gpu_zerout<int>(void * mutable_gpu_data, const int count, int th);
template void caffe_gpu_zerout<unsigned int>(void * mutable_gpu_data, const int count, unsigned int th);
template void caffe_gpu_zerout<float>(void * mutable_gpu_data, const int count, float th);
template void caffe_gpu_zerout<double>(void * mutable_gpu_data, const int count, double th);

//template <>
//void caffe_gpu_zerout<int>(void * mutable_gpu_data, int count, int th){
//	zerout_kernel<<<32768,256>>>(mutable_gpu_data,  count,  th);
//}
//
//template <>
//void caffe_gpu_zerout<float>(void * mutable_gpu_data, int count, float th){
//	zerout_kernel<<<32768,256>>>(mutable_gpu_data,  count,  th);
//}
//
//template <>
//void caffe_gpu_zerout<double>(void * mutable_gpu_data, int count, double th){
//	zerout_kernel<<<32768,256>>>(mutable_gpu_data,  count,  th);
//}

void caffe_gpu_memcpy(const size_t N, const void* X, void* Y) {
  if (X != Y) {
    CUDA_CHECK(cudaMemcpy(Y, X, N, cudaMemcpyDefault));  // NOLINT(caffe/alt_fn)
  }
}

template <>
void caffe_gpu_scal<float>(const int N, const float alpha, float *X) {
  CUBLAS_CHECK(cublasSscal(Caffe::cublas_handle(), N, &alpha, X, 1));
}

template <>
void caffe_gpu_scal<double>(const int N, const double alpha, double *X) {
  CUBLAS_CHECK(cublasDscal(Caffe::cublas_handle(), N, &alpha, X, 1));
}

template <>
void caffe_gpu_axpby<float>(const int N, const float alpha, const float* X,
    const float beta, float* Y) {
  caffe_gpu_scal<float>(N, beta, Y);
  caffe_gpu_axpy<float>(N, alpha, X, Y);
}

template <>
void caffe_gpu_axpby<double>(const int N, const double alpha, const double* X,
    const double beta, double* Y) {
  caffe_gpu_scal<double>(N, beta, Y);
  caffe_gpu_axpy<double>(N, alpha, X, Y);
}

template <>
void caffe_gpu_dot<float>(const int n, const float* x, const float* y,
    float* out) {
  CUBLAS_CHECK(cublasSdot(Caffe::cublas_handle(), n, x, 1, y, 1, out));
}

template <>
void caffe_gpu_dot<double>(const int n, const double* x, const double* y,
    double * out) {
  CUBLAS_CHECK(cublasDdot(Caffe::cublas_handle(), n, x, 1, y, 1, out));
}

template <>
void caffe_gpu_asum<float>(const int n, const float* x, float* y, int stride) {
  CUBLAS_CHECK(cublasSasum(Caffe::cublas_handle(), n, x, stride, y));
}

template <>
void caffe_gpu_asum<double>(const int n, const double* x, double* y, int stride) {
  CUBLAS_CHECK(cublasDasum(Caffe::cublas_handle(), n, x, stride, y));
}

template <>
void caffe_gpu_scale<float>(const int n, const float alpha, const float *x,
                            float* y) {
  CUBLAS_CHECK(cublasScopy(Caffe::cublas_handle(), n, x, 1, y, 1));
  CUBLAS_CHECK(cublasSscal(Caffe::cublas_handle(), n, &alpha, y, 1));
}

template <>
void caffe_gpu_scale<double>(const int n, const double alpha, const double *x,
                             double* y) {
  CUBLAS_CHECK(cublasDcopy(Caffe::cublas_handle(), n, x, 1, y, 1));
  CUBLAS_CHECK(cublasDscal(Caffe::cublas_handle(), n, &alpha, y, 1));
}

//Usage: dim3 block(c,1); dim3 thread(1,n); col_group_lasso_kernel<<<block,thread>>>(n,c,x,y);
template  <typename Dtype>
__global__ void col_group_lasso_kernel(const int n, const int c, const Dtype *x, Dtype* y){
	int n_offset = 0;
//BUG: THE n must be multiple times of blockDim.y in current implementation !!!
		//initialize y
		while(n_offset<n){
			int idx1 = (n_offset+threadIdx.y)*gridDim.x+blockIdx.x;
			y[idx1] = x[idx1]*x[idx1];
			n_offset += blockDim.y;
		}
		__syncthreads();

		//sum along columns
		n_offset=0;
		Dtype res = 0;
		while(n_offset<n){
			int len = (n_offset + blockDim.y)<n ? blockDim.y : (n-n_offset);//valid threads to process
			while(len/2>0){
				if(threadIdx.y<len/2){
					int idx1 = (n_offset+threadIdx.y)*gridDim.x+blockIdx.x;
					int idx2 = (n_offset+threadIdx.y+(len+1)/2)*gridDim.x+blockIdx.x;
					y[idx1] += y[idx2];
				}
				__syncthreads();
				len=(len+1)/2;
			}

			res += y[n_offset*gridDim.x+blockIdx.x];
			n_offset += blockDim.y;
		}
		__syncthreads();

		//copy
		n_offset=0;
		while(n_offset<n){
			int idx1 = (n_offset+threadIdx.y)*gridDim.x+blockIdx.x;
		  	if(res){
		  		y[idx1] = Dtype(sqrt(res));
		  	}else{
		  		y[idx1] = Dtype(0);
		  	}
		  	n_offset += blockDim.y;
		}
}

//Usage: dim3 block(1,n); dim3 thread(c,1); row_group_lasso_kernel<<<block,thread>>>(n,c,x,y);
template  <typename Dtype>
__global__ void row_group_lasso_kernel(const int n, const int c, const Dtype *x, Dtype* y){
	int c_offset = 0;
//BUG: THE c must be multiple times of blockDim.x in current implementation !!!
		//initialize y
		while(c_offset<c){
			int idx1 = blockIdx.y * blockDim.x + c_offset + threadIdx.x;
			y[idx1] = x[idx1]*x[idx1];
			c_offset += blockDim.x;
		}
		__syncthreads();

		//sum along rows
		c_offset=0;
		Dtype res = 0;
		while(c_offset<c){
			int len = (c_offset + blockDim.x)<c ? blockDim.x : (c-c_offset);//valid threads to process
			while(len/2>0){
				if(threadIdx.x<len/2){
					int idx1 = blockIdx.y * blockDim.x + c_offset + threadIdx.x;
					int idx2 = blockIdx.y * blockDim.x + c_offset + threadIdx.x + (len+1)/2;
					y[idx1] += y[idx2];
				}
				__syncthreads();
				len=(len+1)/2;
			}

			res += y[blockIdx.y * blockDim.x + c_offset];
			c_offset += blockDim.x;
		}
		__syncthreads();

		//copy
		c_offset=0;
		while(c_offset<c){
			int idx1 = blockIdx.y * blockDim.x + c_offset + threadIdx.x;
		  	if(res){
		  		y[idx1] = Dtype(sqrt(res));
		  	}else{
		  		y[idx1] = Dtype(0);
		  	}
		  	c_offset += blockDim.x;
		}
}

template <>
void caffe_gpu_group_lasso<int>(const int n, const int c, const int* x, int* y, bool along_column_or_row){
	NOT_IMPLEMENTED;
}

template <>
void caffe_gpu_group_lasso<unsigned int>(const int n, const int c, const unsigned int* x, unsigned int* y, bool along_column_or_row){
	NOT_IMPLEMENTED;
}

template <>
void caffe_gpu_group_lasso<float>(const int n, const int c, const float* x, float* y, bool along_column_or_row){
	if(along_column_or_row){
		dim3 block(c,1);
		dim3 thread(1,n);
		col_group_lasso_kernel<<<block,thread>>>(n,c,x,y);
	}else{
		dim3 block(1,n);
		dim3 thread(c,1);
		row_group_lasso_kernel<<<block,thread>>>(n,c,x,y);
	}
}

template <>
void caffe_gpu_group_lasso<double>(const int n, const int c, const double* x, double* y, bool along_column_or_row){
	if(along_column_or_row){
		dim3 block(c,1);
		dim3 thread(1,n);
		col_group_lasso_kernel<<<block,thread>>>(n,c,x,y);
	}else{
		dim3 block(1,n);
		dim3 thread(c,1);
		row_group_lasso_kernel<<<block,thread>>>(n,c,x,y);
	}
}

template <typename Dtype>
__global__ void set_kernel(const int n, const Dtype alpha, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] = alpha;
  }
}

template <typename Dtype>
void caffe_gpu_set(const int N, const Dtype alpha, Dtype* Y) {
  if (alpha == 0) {
    CUDA_CHECK(cudaMemset(Y, 0, sizeof(Dtype) * N));  // NOLINT(caffe/alt_fn)
    return;
  }
  // NOLINT_NEXT_LINE(whitespace/operators)
  set_kernel<Dtype><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, alpha, Y);
}

template void caffe_gpu_set<int>(const int N, const int alpha, int* Y);
template void caffe_gpu_set<float>(const int N, const float alpha, float* Y);
template void caffe_gpu_set<double>(const int N, const double alpha, double* Y);

template <typename Dtype>
__global__ void add_scalar_kernel(const int n, const Dtype alpha, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] += alpha;
  }
}

template <>
void caffe_gpu_add_scalar(const int N, const float alpha, float* Y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  add_scalar_kernel<float><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, alpha, Y);
}

template <>
void caffe_gpu_add_scalar(const int N, const double alpha, double* Y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  add_scalar_kernel<double><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, alpha, Y);
}

template <typename Dtype>
__global__ void add_kernel(const int n, const Dtype* a,
    const Dtype* b, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] = a[index] + b[index];
  }
}

template <>
void caffe_gpu_add<float>(const int N, const float* a, const float* b,
    float* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  add_kernel<float><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, b, y);
}

template <>
void caffe_gpu_add<double>(const int N, const double* a, const double* b,
    double* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  add_kernel<double><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, b, y);
}

template <typename Dtype>
__global__ void sub_kernel(const int n, const Dtype* a,
    const Dtype* b, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] = a[index] - b[index];
  }
}

template <>
void caffe_gpu_sub<float>(const int N, const float* a, const float* b,
    float* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  sub_kernel<float><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, b, y);
}

template <>
void caffe_gpu_sub<double>(const int N, const double* a, const double* b,
    double* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  sub_kernel<double><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, b, y);
}

template <typename Dtype>
__global__ void mul_kernel(const int n, const Dtype* a,
    const Dtype* b, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] = a[index] * b[index];
  }
}

template <>
void caffe_gpu_mul<float>(const int N, const float* a,
    const float* b, float* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  mul_kernel<float><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, b, y);
}

template <>
void caffe_gpu_mul<double>(const int N, const double* a,
    const double* b, double* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  mul_kernel<double><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, b, y);
}

template <typename Dtype>
__global__ void div_kernel(const int n, const Dtype* a,
    const Dtype* b, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] = a[index] / b[index];
  }
}

template <typename Dtype>
__global__ void div_checkzero_kernel(const int n, const Dtype* a,
    const Dtype* b, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] = b[index] ? (a[index] / b[index]) : Dtype(0);
  }
}

template <>
void caffe_gpu_div<float>(const int N, const float* a,
    const float* b, float* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  div_kernel<float><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, b, y);
}

template <>
void caffe_gpu_div<double>(const int N, const double* a,
    const double* b, double* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  div_kernel<double><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, b, y);
}

template <>
void caffe_gpu_div_checkzero<float>(const int N, const float* a,
    const float* b, float* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  div_checkzero_kernel<float><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, b, y);
}

template <>
void caffe_gpu_div_checkzero<double>(const int N, const double* a,
    const double* b, double* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
	div_checkzero_kernel<double><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, b, y);
}

template <typename Dtype>
__global__ void abs_kernel(const int n, const Dtype* a, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] = abs(a[index]);
  }
}

template <>
void caffe_gpu_abs<float>(const int N, const float* a, float* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  abs_kernel<float><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, y);
}

template <>
void caffe_gpu_abs<double>(const int N, const double* a, double* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  abs_kernel<double><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, y);
}


template <typename Dtype>
__global__ void exp_kernel(const int n, const Dtype* a, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] = exp(a[index]);
  }
}

template <>
void caffe_gpu_exp<float>(const int N, const float* a, float* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  exp_kernel<float><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, y);
}

template <>
void caffe_gpu_exp<double>(const int N, const double* a, double* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  exp_kernel<double><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, y);
}

template <typename Dtype>
__global__ void log_kernel(const int n, const Dtype* a, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] = log(a[index]);
  }
}

template <>
void caffe_gpu_log<float>(const int N, const float* a, float* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  log_kernel<float><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, y);
}

template <>
void caffe_gpu_log<double>(const int N, const double* a, double* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  log_kernel<double><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, y);
}

template <typename Dtype>
__global__ void powx_kernel(const int n, const Dtype* a,
    const Dtype alpha, Dtype* y) {
  CUDA_KERNEL_LOOP(index, n) {
    y[index] = pow(a[index], alpha);
  }
}

template <>
void caffe_gpu_powx<float>(const int N, const float* a,
    const float alpha, float* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  powx_kernel<float><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, alpha, y);
}

template <>
void caffe_gpu_powx<double>(const int N, const double* a,
    const double alpha, double* y) {
  // NOLINT_NEXT_LINE(whitespace/operators)
  powx_kernel<double><<<CAFFE_GET_BLOCKS(N), CAFFE_CUDA_NUM_THREADS>>>(
      N, a, alpha, y);
}

DEFINE_AND_INSTANTIATE_GPU_UNARY_FUNC(sign, y[index] = (Dtype(0) < x[index])
                                      - (x[index] < Dtype(0)));
DEFINE_AND_INSTANTIATE_GPU_UNARY_FUNC(sgnbit, y[index] = signbit(x[index]));
DEFINE_AND_INSTANTIATE_GPU_UNARY_FUNC(if_zerout, y[index] = ((x[index] < Dtype(0.0001) && x[index] > Dtype(-0.0001) ) ? 1 : 0) );

void caffe_gpu_rng_uniform(const int n, unsigned int* r) {
  CURAND_CHECK(curandGenerate(Caffe::curand_generator(), r, n));
}

template <>
void caffe_gpu_rng_uniform<float>(const int n, const float a, const float b,
                                  float* r) {
  CURAND_CHECK(curandGenerateUniform(Caffe::curand_generator(), r, n));
  const float range = b - a;
  if (range != static_cast<float>(1)) {
    caffe_gpu_scal(n, range, r);
  }
  if (a != static_cast<float>(0)) {
    caffe_gpu_add_scalar(n, a, r);
  }
}

template <>
void caffe_gpu_rng_uniform<double>(const int n, const double a, const double b,
                                   double* r) {
  CURAND_CHECK(curandGenerateUniformDouble(Caffe::curand_generator(), r, n));
  const double range = b - a;
  if (range != static_cast<double>(1)) {
    caffe_gpu_scal(n, range, r);
  }
  if (a != static_cast<double>(0)) {
    caffe_gpu_add_scalar(n, a, r);
  }
}

template <>
void caffe_gpu_rng_gaussian(const int n, const float mu, const float sigma,
                            float* r) {
  CURAND_CHECK(
      curandGenerateNormal(Caffe::curand_generator(), r, n, mu, sigma));
}

template <>
void caffe_gpu_rng_gaussian(const int n, const double mu, const double sigma,
                            double* r) {
  CURAND_CHECK(
      curandGenerateNormalDouble(Caffe::curand_generator(), r, n, mu, sigma));
}

}  // namespace caffe
