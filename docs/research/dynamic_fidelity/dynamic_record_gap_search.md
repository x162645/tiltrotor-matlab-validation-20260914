# XV-15 悬停动态记录缺口检索（TM-86009/TM-89404 等）

## 检索目标与判定

目标是找出**同一工况、可复核且公开**的 XV-15 悬停记录，至少同时有实际 collective/执行器输入，以及旋翼推力或升沉响应，并能确认 RPM、质量等边界。仅有传递函数、摘要或“做过 collective sweep”的文字不计为配对时历。图中若同时画出输入和输出，可判为“可数字化配对”，但必须记录输入是否为实际旋翼总距，而不是驾驶舱 power lever；不得把功率杆混控或 governor 后的桨距自行推断为实际桨距。

## 发现的图/表与精确边界

### NASA TM-89404（Tischler & Kaletka, 1986）

官方记录：[NTRS 19870018198](https://ntrs.nasa.gov/citations/19870018198)，本地归档 `06_NASA_TM_89404_XV15_Frequency_and_Time_Domain_Identification.pdf`。

- **Fig. 13，PDF 第18页（报告印刷页码 16）** 同时给出可数字化的输入图和模型/飞行响应对照：子图(a)为 `power lever input`，横轴 TIME 0–28 s，纵轴约 54–64（功率杆百分数）；子图(b)/(c)为频域模型/时域模型的垂向加速度对照，纵轴约 0.90–1.10 g。图题是 “Comparison of vertical-acceleration response prediction for step power lever input”。这满足“输入—升沉响应同时显示”的形式条件，但输入是驾驶舱 power lever（垂向控制），不是已标定的旋翼实际 collective/执行器位置；图中没有旋翼推力或桨毂载荷通道，也未公开分离后的原始数组。
- 报告 PDF 第10页（印刷页码 8）说明 heave response 先由 collective sweeps 确定，随后辨识 pitch；第17–18页（印刷页码 15–16）说明 power-step 响应与带噪的垂向加速度飞行数据比较。正文没有给出 collective actuator 角度的同步时历，也没有给出每个图对应的 RPM、总质量/重心和旋翼推力时历。故 Fig.13 可作为**power-lever→垂向加速度**的流程和图形参照，不能作为实际总距→载荷外部验证。
- 仪器说明（PDF 第12页附近）有角速度、姿态和线加速度；悬停速度测量不可用，速度由加速度积分并施加边界条件重构。这进一步限制了从该报告获得独立升沉速度真值的能力。

### NASA TM-86009（Tischler et al., 1984）

官方 PDF：[NTRS 19840026374](https://ntrs.nasa.gov/api/citations/19840026374/downloads/19840026374.pdf)，本地归档 `05_NASA_TM_86009_XV15_Frequency_Domain_Models.pdf`。

- **Table 1，PDF 第14页（报告印刷页码 75–12）** 给出悬停纵向传递函数
  \(a_z/\delta_c=-0.108e^{-0.005s}/(s+0.115)\)，单位标注为 `g / % power lever`；这仍是 power lever 输入，不是实际旋翼总距。
- PDF 第15页（印刷页码 75–13）文字写明 “Analyses on the vertical response to collective (\(a_z/\delta_c\)) showed the same excellent response correlation”，并说阶跃响应运行长度约 10 s；该页实际展示的是 **Fig.16/17 的 pedal/rudder→yaw-rate**，没有把 collective 输入和垂向响应画成可复核的同步时历。因而这是一条方法叙述和低阶模型参数，不是公开的 collective—heave 原始记录。
- 报告第14页指出悬停/巡航传递函数用同一记录控制输入作阶跃验证，但悬停工况的图示主要是方向轴响应。没有找到旋翼 thrust/load 或 collective actuator position 的时历、RPM/质量配对记录。

### NASA TM-81244（Dugan et al., 1980）

官方 PDF：[NTRS 19810001546](https://ntrs.nasa.gov/archive/nasa/casi.ntrs.nasa.gov/19810001546.pdf)，本地归档 `02_NASA_TM_81244_The_XV15_Tilt_Rotor_Research_Aircraft.pdf`。

- PDF 第4–5页说明直升机模式下 pilot power lever 同时施加两台旋翼的 collective blade pitch；blade-pitch/beta governor 还会叠加桨距以保持 pilot-selected RPM。该控制结构说明了为什么 power lever 不能直接当作实际总距。
- PDF 第4页给出设计总重 13,000 lb；第8页给出转换到 airplane mode 时由 governor 将转速从 98%（589 rpm）降至 86%（517 rpm）的示例。它是系统/设计资料，**没有**与 TM-89404 Fig.13 同步的输入—升沉—推力记录，不能补齐动态工况边界。

### NASA TM-86833（Felker, Betzina & Signor, 1985）

官方 PDF：[NTRS 19860005773](https://ntrs.nasa.gov/api/citations/19860005773/downloads/19860005773.pdf)，本地归档 `04_NASA_TM_86833_Full_Scale_XV15_Rotor_Hover_Test.pdf`。

- PDF 第6–8页说明全尺寸金属桨 OARF 悬停试验采用旋翼平衡、冗余 load cells 和仪器化驱动轴，报告推力、扭矩、尾流及载荷。PDF 第8页明确 CT/σ–collective-pitch 曲线的 collective pitch 来自 collective actuator position，控制系统几何非线性误差估计小于 ±1°。
- 这构成高价值的**稳态执行器位置→桨距→载荷**证据；但公开正文是平均工况曲线、表格和载荷统计，没有同步 actuator-position、thrust/load、heave velocity/acceleration 原始时间序列，也不是阶跃试验。因此不能与 TM-89404 Fig.13 拼接成一条动态记录。

## 结论：是否找到可直接用于当前 D16 的公开记录

找到一条可数字化的 XV-15 悬停**power lever→垂向加速度**配对图（TM-89404 Fig.13），但没有找到同时满足“实际旋翼总距/执行器位置 + 旋翼推力或桨毂载荷 + 升沉响应 + RPM/质量边界”的公开时间历史。TM-86009 只给 power-lever 传递函数和 collective-sweep 的文字说明；TM-86833 只给稳态 actuator-position 与载荷关系；TM-81244 说明 governor/控制混控及设计 RPM/重量，未给动态配对。

因此当前公开证据可支持两件事：一是用 TM-86833 约束稳态总距—载荷映射并保留 ±1° 映射敏感性；二是用 TM-89404 Fig.13 作为动态辨识流程的图形参照。它不能提供 D16 所需的独立实际总距—载荷—升沉动态资格，也不能把 power lever→垂向加速度误称为 rotor collective→thrust/heave 真值。下一步若要关闭缺口，必须取得同一记录中的 collective actuator/受载总距标定、旋翼推力或桨毂载荷、升沉速度/加速度及 RPM/质量工况。

## 来源与文件身份

本检索只读取 `E:\tavernchara\XV15_component_model_reference_pack\papers` 的现有归档和 NASA NTRS 官方页面/PDF；没有下载新数据、没有从图像生成数值 CSV，也没有修改仓库或旧证据包。
