# 整机同步外部验证数据合同（V1）

当前整机动态精度验证被同步数据阻断。`validation/read_full_aircraft_sync_csv.m` 提供严格的数据入口，避免把名义指令、反算输入或不同记录窗口混作独立验证。

CSV 必须使用 SI 单位，并至少包含统一的 10 个实际输入：`collective_actual_rad`, `diff_collective_actual_rad`, `cyclic_long_actual_rad`, `diff_cyclic_actual_rad`, `lateral_cyclic_actual_rad`, `aileron_actual_rad`, `elevator_actual_rad`, `rudder_actual_rad`, `nacelle_torque_left_Nm`, `nacelle_torque_right_Nm`；以及 `time_s`, `nacelle_left_rad`, `nacelle_right_rad`, `rotor_speed_left_rad_s`, `rotor_speed_right_rad_s`, `rotor_thrust_left_N`, `rotor_thrust_right_N`, `u_m_s`, `v_m_s`, `w_m_s`, `p_rad_s`, `q_rad_s`, `r_rad_s`, `phi_rad`, `theta_rad`, `psi_rad`, `altitude_m`。

`collective_actual_rad` 必须是实际受载总距或由执行器位置得到的受载桨距，不能用名义指令替代。若该通道缺失，入口不会反算输入来消除外部误差。

入口拒绝缺列、非数值、NaN/Inf、非递增时间和明显不均匀采样。通过入口只表示数据具备进入外部预测检验的格式条件，不表示模型已经验证；质量、重心、惯量、构型、风场、延迟和来源仍需单独登记。

`tests/check_full_aircraft_sync_schema.m` 使用临时合成表，仅测试合同和拒绝逻辑，不产生外部精度证据。
