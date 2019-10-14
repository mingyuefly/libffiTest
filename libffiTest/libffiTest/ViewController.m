//
//  ViewController.m
//  libffiTest
//
//  Created by Gguomingyue on 2019/10/12.
//  Copyright © 2019 Gmingyue. All rights reserved.
//

#import "ViewController.h"
#import <objc/runtime.h>
#import <ffi.h>
#import <dlfcn.h>

@interface LibffiTest : NSObject

@end

@implementation LibffiTest

-(NSInteger)testFunctionArgumentA:(NSInteger)argA ArgumentB:(NSInteger)argB
{
    NSLog(@"testFunctionArgumentA");
    return argA + argB;
}

@end


// 计算矩形面积
int rectangleArea(int length, int width) {
    printf("Rectangle length is %d, and with is %d, so area is %d \n", length, width, length * width);
    return length * width;
}

void run() {
    // dlsym 返回 rectangleArea 函数指针
    // 在知道要调用的函数时，可通过函数名字字符串和dlsym函数得到函数指针，从而调用
    int (*fun)(int a, int b);
    fun = dlsym(RTLD_DEFAULT, "rectangleArea");
    int area = fun(2, 3);
    printf("area = %d\n", area);
}

void testFFICall()
{
    // 通过类名，方法名，参数，参数个数可以调用c函数
    int nums = 4;
    ffi_cif cif;
    //argumentTypes可以根据nums确定长度
    ffi_type *argumentTypes[] = {&ffi_type_pointer, &ffi_type_pointer, &ffi_type_pointer, &ffi_type_pointer};
 
    // 4为argumentTypes的参数个数
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, nums, &ffi_type_pointer, argumentTypes);
    
    //LibffiTest *test = [[LibffiTest alloc] init];
    //SEL selector = @selector(testFunctionArgumentA:ArgumentB:);
    Class class = NSClassFromString(@"LibffiTest");
    id test = [class new];
    SEL selector = NSSelectorFromString(@"testFunctionArgumentA:ArgumentB:");
    NSInteger argA = 123;
    NSInteger argB = 456;
    void * arguments[] = {&test, selector, &argA, &argB};
    IMP imp = [test methodForSelector:selector];
    imp();
    
    NSInteger retValue;
    ffi_call(&cif, imp, &retValue, arguments);
    NSLog(@"retValue = %ld", (long)retValue);
}

void closureCalled(ffi_cif *cif, void *ret, void **args, void * userdata)
{
    NSInteger argA = *((NSInteger *)args[2]);
    NSInteger argB = *((NSInteger *)args[3]);
    *((NSInteger *)ret) = argA * argB;
}

void testFFIClosure() {
    ffi_cif cif;
    ffi_type * argumentTypes[] = {&ffi_type_pointer, &ffi_type_pointer, &ffi_type_sint32, &ffi_type_sint32};
    ffi_prep_cif(&cif, FFI_DEFAULT_ABI, 4, &ffi_type_pointer, argumentTypes);
    IMP newIMP;
    ffi_closure * closure = ffi_closure_alloc(sizeof(ffi_closure), (void *)&newIMP);
    // 自定义closureCalled的函数内容就可以动态hook类的方法
    // 或者可以说把closureCalled做为一个参数动态绑定一个类方法
    ffi_prep_closure_loc(closure, &cif, closureCalled, NULL, NULL);
    
    // 重要的是可以构造一个newIMP
    Method method = class_getInstanceMethod([LibffiTest class], @selector(testFunctionArgumentA:ArgumentB:));
    method_setImplementation(method, newIMP);
    
    LibffiTest *test = [[LibffiTest alloc] init];
    NSInteger ret = [test testFunctionArgumentA:123 ArgumentB:456];
    NSLog(@"ret = %ld", (long)ret);
}

int testFunc(int m, int n) {
  printf("params: %d %d \n", n, m);
  return n+m;
}

void testFunction()
{
    //拿函数指针
    void* functionPtr = dlsym(RTLD_DEFAULT, "testFunc");
    int argCount = 2;

    //按ffi要求组装好参数类型数组
    ffi_type **ffiArgTypes = alloca(sizeof(ffi_type *) *argCount);
    ffiArgTypes[0] = &ffi_type_sint;
    ffiArgTypes[1] = &ffi_type_sint;

     //按ffi要求组装好参数数据数组
    void **ffiArgs = alloca(sizeof(void *) *argCount);
    void *ffiArgPtr = alloca(ffiArgTypes[0]->size);
    int *argPtr = ffiArgPtr;
    *argPtr = 1;
    ffiArgs[0] = ffiArgPtr;

    void *ffiArgPtr2 = alloca(ffiArgTypes[1]->size);
    int *argPtr2 = ffiArgPtr2;
    *argPtr2 = 2;
    ffiArgs[1] = ffiArgPtr2;

    //生成 ffi_cfi 对象，保存函数参数个数/类型等信息，相当于一个函数原型
    ffi_cif cif;
    ffi_type *returnFfiType = &ffi_type_sint;
    ffi_status ffiPrepStatus = ffi_prep_cif_var(&cif, FFI_DEFAULT_ABI, (unsigned int)0, (unsigned int)argCount, returnFfiType, ffiArgTypes);

    if (ffiPrepStatus == FFI_OK) {
      //生成用于保存返回值的内存
      void *returnPtr = NULL;
      if (returnFfiType->size) {
        returnPtr = alloca(returnFfiType->size);
      }
      //根据cif函数原型，函数指针，返回值内存指针，函数参数数据调用这个函数
      ffi_call(&cif, functionPtr, returnPtr, ffiArgs);

      //拿到返回值
      int returnValue = *(int *)returnPtr;
      printf("ret: %d \n", returnValue);
    }
}

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    testFFICall();
    run();
    testFFIClosure();
    testFunction();
}


@end
