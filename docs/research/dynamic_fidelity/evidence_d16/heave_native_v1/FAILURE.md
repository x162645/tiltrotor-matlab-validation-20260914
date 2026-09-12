2026-09-12 UTC，源码e0750c6。新增升沉runner把原始输出cell变量命名all，遮蔽MATLAB all函数，首个ODE右端有限值断言触发索引异常。没有产生升沉轨迹或指标。改名rawOutputs，物理、参数、数据、容差不变；原运行日志保留。
