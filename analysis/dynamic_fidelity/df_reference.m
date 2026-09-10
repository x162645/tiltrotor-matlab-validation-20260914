function ref = df_reference(caseId)
%DF_REFERENCE 读取已核原页的动态响应基准，不生成飞机物理参数。
% NASA TM89428: hover Eq4.8-4.10/Table4.1; cruise Eq5.10/5.12.
% 输入输出保留原文符号/单位，未知同工况参数不默认填充。
if ~(ischar(caseId) && isrow(caseId) && ~isempty(caseId))
    error('df_reference:InvalidId','caseId must be a nonempty character row.');
end
p=fullfile(fileparts(mfilename('fullpath')),'data','tm89428_reference_cases.json');
r=jsondecode(fileread(p)); ids={r.cases.id}; ix=find(strcmp(ids,caseId));
if ~isscalar(ix),error('df_reference:UnknownCase','Unknown reference case: %s',caseId);end
ref=r.cases(ix);ref.numerator=ref.numerator(:).';ref.denominator=ref.denominator(:).';
ref.frequency_band_rad_s=ref.frequency_band_rad_s(:).';
ref.reference_library_role=r.role;
end
