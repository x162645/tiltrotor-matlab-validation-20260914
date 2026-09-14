function [CL,CD,meta]=gtrs_horizontal_tail_source_coefficients(alphaBase_deg,elevator_deg,Mach)
%GTRS_HORIZONTAL_TAIL_SOURCE_COEFFICIENTS CR-166536 A85/A86, Tables 5-I..IV.
% alphaBase excludes the elevator equivalent-incidence contribution.
% M<.2: CL(alphaBase,elevator) from 5-I. M>=.2: CL(alphaBase+
% Ke*tau*elevator,0,M) from 5-II. CD uses the latter angle for all Mach.
% Source-node interpolation is linear; no extrapolation or target fitting.
% PDF pp153-154/A85-A86; pp406-414/B56-B64. Angles in source/code degrees.
% Source PDF SHA256 a2013a314af5beb0c5e9bc5bbeb26f99be9a8aa63f2ebe07deaaf11d0d44d67d.
validateattributes(alphaBase_deg,{'numeric'},{'real','finite','scalar'});
validateattributes(elevator_deg,{'numeric'},{'real','finite','scalar'});
validateattributes(Mach,{'numeric'},{'real','finite','scalar'});
if abs(elevator_deg)>20 || Mach<0 || Mach>.6
 error('gtrs_horizontal_tail_source_coefficients:OutsideDomain','Require elevator +/-20deg and Mach 0..0.6.');
end
XKe=interp1([0 .2 .4 .5 .6 .7],[1 1 .965 .950 .930 .900],Mach,'linear');
Ke=XKe-.24*max(abs(elevator_deg)-15,0)/15;
alphaEquivalent=alphaBase_deg+Ke*.518*elevator_deg;
persistent D
if isempty(D),D=load_source();end
if Mach<.2
 T=gtrs_heli_tail_tables();
 if alphaBase_deg<T.liftAlpha_deg(1)||alphaBase_deg>T.liftAlpha_deg(end)
  error('gtrs_horizontal_tail_source_coefficients:OutsideAlpha','Low-Mach CL subset requires alpha -20..20deg.');
 end
 CL=interp2(T.elevator_deg,T.liftAlpha_deg,T.CL,elevator_deg,alphaBase_deg,'linear');
else
 CL=lookup(D.lift,alphaEquivalent,Mach);
end
CD=lookup(D.drag,alphaEquivalent,max(.2,Mach));
meta=struct('identity','CR166536_A85_A86_T5_SOURCE_COEFFICIENTS',...
 'sourceEquations','CR-166536 A-85/A-86','sourceTables','5-I/5-II/5-III/5-IV',...
 'Mach',Mach,'elevator_deg',elevator_deg,'alphaBase_deg',alphaBase_deg,...
 'alphaEquivalent_deg',alphaEquivalent,'XKe',XKe,'Ke',Ke,...
 'interpolation','LINEAR_WITHIN_SOURCE_NODES','fittedToTarget',false);
end

function y=lookup(groups,a,m)
grid=[.2 .4 .5 .6]; k=find(abs(grid-m)<1e-12,1);
if ~isempty(k),lo=k;hi=k;w=0;else
 hi=find(grid>m,1);lo=hi-1;w=(m-grid(lo))/(grid(hi)-grid(lo));
end
ylo=one(groups{lo},a);yhi=one(groups{hi},a);y=(1-w)*ylo+w*yhi;
end
function y=one(g,a)
if a<g(1,1)-1e-10||a>g(end,1)+1e-10
 error('gtrs_horizontal_tail_source_coefficients:OutsideAlpha','Equivalent alpha outside required source column.');
end
y=interp1(g(:,1),g(:,2),a,'linear');
end
function D=load_source()
root=fileparts(fileparts(mfilename('fullpath')));
T=readtable(fullfile(root,'analysis','validation_whole_aircraft_trim','data','CR166536_ALL_CELLS.csv'),...
 'Delimiter',',','ReadVariableNames',true,'HeaderLines',0,'TextType','string','VariableNamingRule','preserve');
sourceTable=T{:,1};
D.lift=cell(1,4);D.drag=cell(1,4); labels=["0-0.2" "0.4" "0.5" "0.6"];
mask=ismember(sourceTable,["5-I" "5-II" "5-III"]) & isfinite(T.value);
indices=find(mask);
for i=indices(:).'
 c=jsondecode(char(T.coordinates_json(i)));
 if str2double(c.elevator_deg)~=0,continue;end
 k=find(labels==string(c.mach_label),1);if isempty(k),continue;end
 if sourceTable(i)=="5-III",name='drag';else,name='lift';end
 if strcmp(name,'lift')&&k==1&&sourceTable(i)~="5-I",continue;end
 D.(name){k}(end+1,:)=[str2double(c.alpha_deg),T.value(i)];
end
for k=1:4
 D.lift{k}=sortrows(D.lift{k},1);D.drag{k}=sortrows(D.drag{k},1);
 assert(size(D.lift{k},1)>=2&&size(D.drag{k},1)>=2,'Source column missing.');
end
end
