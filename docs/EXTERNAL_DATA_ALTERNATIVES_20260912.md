# 通用倾转旋翼参数与非 XV-15 验证对象（2026-09-12）

## 结论

通用倾转旋翼模型不需要预先拥有一架真实飞机的全部参数。用户可以设置几何、质量、惯量、旋翼、短舱、执行器和气动数据；模型输出的是该参数集对应的构型。HeliUM 的公开论文明确把模型用于“generic”构型，并通过缩放 XV-15、V-22 和 NASA LCTR2 的几何/惯性/结构属性构造示例飞机，而不是声称这些示例就是某一架真实飞机。

XV-15 的作用是提供一个公开资料较完整、可用于基准验模的已知构型。它不是通用模型运行的必要条件，但若要声明“对 XV-15 的全机动态精度”，就必须使用与 XV-15 对应的参数和外部响应数据。

## HeliUM 如何使用参数和验证

Juhasz 等人的 HeliUM 研究说明：

- HeliUM 源自 NASA GenHel/Howlett 数学模型，后来增加柔性旋翼、自由尾迹、多旋翼和柔性机翼；
- 模型按部件和树形拓扑组装，可表示单旋翼、共轴和倾转旋翼；
- XV-15 验模使用 GTRSIM 手册和示例代码中的公开气动表/输入；缺少桨叶结构数据时，研究者使用 UH-60 桨叶输入块，并明确说明这一替代；
- 验证采用悬停和巡航频率响应，将 HeliUM 与 GTRSIM、系统辨识模型及飞行试验频率扫描比较；结果总体吻合，但悬停横滚幅值约高 5 dB，偏航高频差异归因于桨毂形式不同；
- 对 LCTR 主要与 CAMRAD 进行模型间比较，不能把这种比较等同于实机验证。

来源：

- Juhasz et al., *Flight Dynamic Simulation Modeling of Large Flexible Tiltrotor Aircraft*：<https://www.sjsu.edu/researchfoundation/docs/AHS_2012_Juhasz.pdf>
- Celi, *HeliUM 2 Flight Dynamic Simulation Model*：<https://saemobilus.sae.org/papers/helium-2-flight-dynamic-simulation-model-development-technical-concepts-applications-f-0071-2015-10213>
- Berger et al., generic HeliUM-A tiltrotor：<https://www.sjsu.edu/researchfoundation/docs/VFS_2020_Berger2.pdf>

## 不依赖 XV-15 的公开验证对象

| 对象 | 可获得内容 | 能验证什么 | 不能验证什么 |
|---|---|---|---|
| ERICA/NICETRIP 1:5 模型 | 直升、转换和低速飞机模式；短舱/外翼角度变化；超过 400 个风洞工况；旋翼力矩、叶片弯扭、轴弯和扭矩，以及配平/非配平记录 | 通用倾转旋翼的旋翼-短舱-机翼-机身气动载荷接口、转换构型趋势 | 真实飞机自由飞行操稳、完整传感器时历 |
| ERICA CFD-试验对比 | DNW-LLF 与 ONERA 风洞，约 M=0.17–0.55；全机、倾转翼、短舱和压力分布 | 全机气动载荷、干扰和 4/rev 非定常趋势 | XV-15 专属参数和真实飞行品质 |
| NASA HVAB 旋翼 | 4 叶、直径 11.08 ft；多尖速马赫和总距；性能、叶片气动载荷、转捩、挠度、尾迹和 PIV 数据 | 旋翼推力/功率、气动载荷、诱导和尾迹子模型 | 双旋翼整机耦合与过渡动态 |
| DEVCOM/NASA TRAST | 几何、结构、惯性、气动属性；地面振动和涡振稳定性试验；可调桨叶/短舱结构参数 | 旋翼-短舱-机翼气动弹性、模态和稳定性 | 全机配平和飞行操稳 |

来源：

- ERICA 风洞与旋翼载荷：<https://dspace-erf.nlr.nl/items/a6363cb9-304f-4c3f-88b9-08f770504dd7>
- ERICA 多代码 CFD-试验验证：<https://elib.dlr.de/91375/1/ERF2014_036B.pdf>
- ERICA 1:8 风洞资料：<https://re.public.polimi.it/handle/11311/584475>
- NASA HVAB：<https://rotorcraft.arc.nasa.gov/HVAB/>
- TRAST ARL-TR-10030：<https://arl.devcom.army.mil/arlreport/arl-tr-10030/>

## 对本项目的实际意义

1. **通用模型可以先不绑定 XV-15。** 先定义一组公开可追溯的通用构型参数，验证旋翼、短舱、机翼和机身的可分离输出。
2. **ERICA 可作为整机气动外部验证对象。** 需要按其比例模型几何、风洞速度、短舱角和测量定义建立专用适配器，不能沿用 XV-15 静态表。
3. **HVAB 和 OARF/WADC 可验证旋翼子模型。** 这能直接改善 CT、CP、FM、载荷和诱导模型，但不能自动证明整机动态精度。
4. **TRAST 可补充结构和模态证据。** 它适合验证短舱/旋翼气动弹性支路，不能替代自由飞行数据。
5. **整机操稳声明仍需要输入-状态同步记录。** 公开风洞数据可支持气动载荷和部分转换趋势；要计算并验证真实飞行品质，还需真实操纵输入、机体状态、时间同步和构型质量属性。

因此，缺少 XV-15 参数不会阻断“通用倾转旋翼方法研究”；它只限制针对 XV-15 的定量验模范围。最可行的路线是：旋翼（HVAB/OARF/WADC）→ 倾转旋翼气动（ERICA）→ 结构模态（TRAST）→ 有同步数据时再做真实整机动态和飞行品质。
