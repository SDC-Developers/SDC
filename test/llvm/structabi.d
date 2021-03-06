// RUN: %sdc %s -S --emit-llvm -o - | FileCheck %s

module structabi;

struct S {
	ulong[4] parts;
	
	this(ulong n) {
		parts[3] = n;
// CHECK-LABEL: define %S9structabi1S @_D9structabi1S6__ctorFMS9structabi1SmZS9structabi1S
// CHECK: %this = alloca %S9structabi1S
// CHECK-NEXT: store %S9structabi1S %arg.this, %S9structabi1S* %this
// CHECK: [[RET:%[a-z0-9\.]+]] = load %S9structabi1S, %S9structabi1S* %this
// CHECK-NEXT: ret %S9structabi1S [[RET:%[a-z0-9\.]+]]
	}
	
	static allocate(ulong n) {
// CHECK-LABEL: define %S9structabi1S* @_D9structabi1S8allocateFMmZPS9structabi1S
// CHECK: [[ALLOC:%[a-z0-9\.]+]] = call noalias i8* @__sd_gc_tl_malloc
// CHECK-NEXT: [[TYPED:%[a-z0-9\.]+]] = bitcast i8* [[ALLOC]] to %S9structabi1S*
// CHECK-NEXT: [[VALUE:%[a-z0-9\.]+]] = call %S9structabi1S @_D9structabi1S6__ctorFMS9structabi1SmZS9structabi1S
// CHECK-NEXT: store %S9structabi1S [[VALUE]], %S9structabi1S* [[TYPED]]
// CHECK-NEXT: ret %S9structabi1S* [[TYPED]]
		return new S(n);
	}
}

struct E {
	ulong[5] parts;
	uint moreparts;
	
	this(ulong n) {
		parts[4] = n;
		moreparts = 23;
// CHECK-LABEL: define void @_D9structabi1E6__ctorFMKS9structabi1EmZv
// CHECK: ret void
	}
	
	static allocate(ulong n) {
// CHECK-LABEL: define %S9structabi1E* @_D9structabi1E8allocateFMmZPS9structabi1E
// CHECK: [[ALLOC:%[a-z0-9\.]+]] = call noalias i8* @__sd_gc_tl_malloc
// CHECK-NEXT: [[TYPED:%[a-z0-9\.]+]] = bitcast i8* [[ALLOC]] to %S9structabi1E*
// CHECK-NEXT: store %S9structabi1E zeroinitializer, %S9structabi1E* [[TYPED]]
// CHECK-NEXT: call void @_D9structabi1E6__ctorFMKS9structabi1EmZv(%S9structabi1E* [[TYPED]], i64 {{.*}})
// CHECK-NEXT: ret %S9structabi1E* [[TYPED]]
		return new E(n);
	}
}

struct F {
	E e;
	S s;
	
	this(ulong n) {
		this(n, n);
// CHECK-LABEL: define void @_D9structabi1F6__ctorFMKS9structabi1FmZv
// CHECK: [[DG0:%[a-z0-9\.]+]] = insertvalue { %S9structabi1F*, void (%S9structabi1F*, i64, i64)* } undef, %S9structabi1F* %this, 0
// CHECK-NEXT: [[DG1:%[a-z0-9\.]+]] = insertvalue { %S9structabi1F*, void (%S9structabi1F*, i64, i64)* } [[DG0]], void (%S9structabi1F*, i64, i64)* @_D9structabi1F6__ctorFMKS9structabi1FmmZv, 1
// CHECK-NEXT: [[THIS:%[a-z0-9\.]+]] = extractvalue { %S9structabi1F*, void (%S9structabi1F*, i64, i64)* } [[DG1]], 0
// CHECK-NEXT: [[CTOR:%[a-z0-9\.]+]] = extractvalue { %S9structabi1F*, void (%S9structabi1F*, i64, i64)* } [[DG1]], 1
// CHECK-NOT: store
// CHECK: call void [[CTOR]](%S9structabi1F* [[THIS]], i64 {{.*}}, i64 {{.*}})
// CHECK-NOT: store
// CHECK: ret void
	}
	
	this(ulong a, ulong b) {
// CHECK-LABEL: define void @_D9structabi1F6__ctorFMKS9structabi1FmmZv
// CHECK: [[ETMP:%[a-z0-9\.]+]] = alloca %S9structabi1E
// CHECK: store %S9structabi1E zeroinitializer, %S9structabi1E* [[ETMP]]
// CHECK: call void {{.*}}(%S9structabi1E* {{.*}}, i64 {{.*}})
// CHECK-NEXT: [[EVAL:%[a-z0-9\.]+]] = load %S9structabi1E, %S9structabi1E* [[ETMP]]
// CHECK-NEXT: store %S9structabi1E [[EVAL]], %S9structabi1E* {{.*}}
// CHECK: [[SVAL:%[a-z0-9\.]+]] = call %S9structabi1S @_D9structabi1S6__ctorFMS9structabi1SmZS9structabi1S
// CHECK-NEXT: store %S9structabi1S [[SVAL]], %S9structabi1S* {{.*}}
// CHECK: ret void
		e = E(a);
		s = S(b);
	}
	
	static allocate(ulong n) {
// CHECK-LABEL: define %S9structabi1F* @_D9structabi1F8allocateFMmZPS9structabi1F
// CHECK: [[ALLOC:%[a-z0-9\.]+]] = call noalias i8* @__sd_gc_tl_malloc
// CHECK-NEXT: [[TYPED:%[a-z0-9\.]+]] = bitcast i8* [[ALLOC]] to %S9structabi1F*
// CHECK-NEXT: store %S9structabi1F zeroinitializer, %S9structabi1F* [[TYPED]]
// CHECK-NEXT: call void @_D9structabi1F6__ctorFMKS9structabi1FmZv(%S9structabi1F* [[TYPED]], i64 {{.*}})
// CHECK-NEXT: ret %S9structabi1F* [[TYPED]]
		return new F(n);
	}
}
