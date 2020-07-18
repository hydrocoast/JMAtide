classdef JMAtide
    %% Properties
    properties
        station
        year
        month
        time
        ndays
        ssh   % sea surface height
        ssha  % sea surface height anomaly
        lon
        lat
        url_ssh
        url_ssha
        unit = 'cm';
    end
    
    %% Properties as constants
    properties (Constant)
        standard_time = 'JST(UTC+9)'
    end
    
    %% Methods (Constructor)
    methods
        %% Constructor
        function obj = JMAtide(varargin)
            if nargin ~= 0
                % % check argument
                narginchk(2,3)
                % %
                if nargin == 2
                    stationname = varargin{1};
                    yearmonth = varargin{2};
                else
                    year0 = varargin{2};
                    year0 = year0(:);
                    month0 = varargin{3};
                    month0 = month0(:);
                    year = repmat(year0,[1,length(month0)])';
                    year = year(:);
                    month = repmat(month0,[length(year0),1]);
                    
                    % % 
                    obj = JMAtide(varargin{1},[year,month]);
                    return                    
                end
                % % 1st argument
                if ischar(stationname); stationname = cellstr(stationname); end
                if ~iscell(stationname); error('Invalid type; stationname must be a char/cell array.'); end
                % % 2nd argument
                if ~ismatrix(yearmonth); error('Invalid type; 2nd argument must be a scalar/matrix.'); end
                [nrow,ncol] = size(yearmonth);
                if nrow==1 && ncol>1
                    if yearmonth(2) > 1900
                    yearmonth=yearmonth'; nrow=ncol; ncol=1;
                    end
                end
                if ncol>2; error('Invalid type; The size of 2nd argument must be 1, N-by-1 or N-by-2.'); end
                if ncol==1
                    nrow = length(yearmonth)*12;
                    year = repmat(yearmonth, [1,12])';
                    year = year(:);
                    month = repmat(1:12',[length(yearmonth),1]);
                else
                    year = yearmonth(:,1);
                    month = yearmonth(:,2);
                end
                if ~isnumeric(year); error('Invalid type; year must be numeric.'); end
                if ~isnumeric(month); error('Invalid type; month must be numeric.'); end
                if any(year<1997); error('Year must be a number above 1997.'); end
                if any([month<1;month>12]); error('Month must be a number from 1 to 12.'); end
                chkstr = datestr(datetime('today'),'YYYYmm');
                cyear = str2double(chkstr(1:4));
                % cmonth = str2double(chkstr(5:6));
                if any(year>cyear+1); error(['Year must be a number below ', chkstr(1:4)]); end
                
                % % set parameters
                year = uint64(year);
                month = uint64(month);
                nstation = length(stationname);
                obj(nstation, nrow) = JMAtide;
                
                % % assign properties
                for i = 1:nstation
                    for j = 1:nrow
                        obj(i,j).station = stationname{i};
                        obj(i,j).year = year(j);
                        obj(i,j).month = month(j);
                    end
                end
                
                % % file URL
                obj = obj.SetProperty;
            end            
        end
    end
    
    %% Methods for data processing
    methods
        %% set properties
        function obj = SetProperty(obj)
            urlbase = 'https://www.data.jma.go.jp/gmd/kaiyou/data/db/tide/genbo/YYYY/YYYYMM/hryYYYYMMSTATION.txt';
            T = JMAtide.CreateReferenceTable;
            for i = 1:numel(obj)
                % % url 
                url1 = urlbase;
                url1 = strrep(url1, 'MM', num2str(obj(i).month,'%02d'));
                url1 = strrep(url1, 'YYYY', num2str(obj(i).year,'%04d'));
                row = find(strcmp(obj(i).station,T.Name_ja), 1);
                if isempty(row)
                    disp(['Station name ', obj(i).station,' was not found.'])
                    continue
                end
                url1 = strrep(url1, 'STATION', T.ID{row});
                url2 = strrep(url1, 'hry', 'dep');
                
                % % 
                obj(i).url_ssh = url1;
                obj(i).url_ssha = url2;
                obj(i).lon = T.Longitude{row};
                obj(i).lat = T.Latitude{row};
            end                            
        end
        
        %% read sea surface height (SSH) from URL
        function obj = LoadSSH(obj)
            % % array
            if numel(obj)>1
                for i = 1:numel(obj)
                    obj(i) = obj(i).LoadSSH;
                end
                return
            end
            
            % % scalar
            % % read from the original source
            txt = webread(obj.url_ssh);
            
            % % calc the number of the day in month
            obj.ndays = length(txt)/137;
            
            % % % assign time series
            obj.time = permute(datetime(obj.year, obj.month, 1):hours(1):datetime(obj.year, obj.month, obj.ndays, 23, 0, 0), [2,1]);
                        
            % % assign SSH
            dat = cell(obj.ndays,24);
            for i = 1:obj.ndays
                for j = 1:24
                    dat{i,j} = txt((i-1)*137+(j-1)*3+1:(i-1)*137+j*3);
                end
            end
            
            % % convert
            dat = cellfun(@strtrim, dat, 'UniformOutput', false);
            dat = cell2mat(cellfun(@str2double, dat, 'UniformOutput', false))';
            if strcmp(obj.unit,'m')
                factor = 0.01;
            else
                factor = 1.0;
            end
            obj.ssh = factor*dat(:);
        end
        
        %% read sea surface height anomaly (SSHA) from URL
        function obj = LoadSSHA(obj)
            % % array
            if numel(obj)>1
                for i = 1:numel(obj)
                    obj(i) = obj(i).LoadSSHA;
                end
                return
            end
            
            % % scalar            
            % % read from the original source
            txt = webread(obj.url_ssha);

            % % calc the number of the day in month
            obj.ndays = length(txt)/107;

            % % assign time series
            obj.time = permute(datetime(obj.year, obj.month, 1):hours(1):datetime(obj.year, obj.month, obj.ndays, 23, 0, 0), [2,1]);
            
            % % assign SSHA
            dat = cell(obj.ndays,24);
            for i = 1:obj.ndays
                for j = 1:24
                    dat{i,j} = txt((i-1)*107+(j-1)*4+1:(i-1)*107+j*4);
                end
            end
            
            % % convert
            dat = cellfun(@strtrim, dat, 'UniformOutput', false);
            dat = cell2mat(cellfun(@str2double, dat, 'UniformOutput', false))';
            if strcmp(obj.unit,'m')
                factor = 0.01;
            else
                factor = 1.0;
            end
            obj.ssha = factor*dat(:);
        end
        
        %% Convert Unit
        function obj = ConvertUnit(obj, unitstr)
            % % check arguments
            if ~ischar(unitstr); error('Unit specification must be "cm" or "m".'); end
            if ~strcmp(unitstr,'cm') && ~strcmp(unitstr,'m'); error('Unit specification must be "cm" or "m".'); end
            
            % % if object array
            if numel(obj)>1
                for i = 1:numel(obj)
                    obj(i) = obj(i).ConvertUnit(unitstr);
                end
                return
            end
            
            % % check
            if strcmp(unitstr,obj.unit)
                disp('No need to convert')
                return
            end
                        
            % % define the factor to convert
            if strcmp(unitstr,'m')
                factor = 0.01;
            else
                factor = 100.0;
            end
                        
            % % convert
            if ~isempty(obj.ssh) ; obj.ssh  = factor*obj.ssh; end
            if ~isempty(obj.ssha); obj.ssha = factor*obj.ssha; end
            obj.unit = unitstr;
        end
    end

    %% Methods for plotting
    methods        
        %% Plot SSH
        function line = PlotSSH(obj)
            % % array
            if numel(obj)>1
                for i = 1:numel(obj)
                    line(i) = obj(i).PlotSSH;
                    hold on
                end
                hold off
                return
            end            
            % % scalar
            line = plot(obj.time, obj.ssh);
        end    
        
        %% Plot SSHA
        function line = PlotSSHA(obj)
            % % array
            if numel(obj)>1
                for i = 1:numel(obj)
                    line(i) = obj(i).PlotSSHA;
                    hold on
                end
                hold off
                return
            end            
            % % scalar
            line = plot(obj.time, obj.ssha);
        end        
    end
    
    %% Methods for output
    methods
        %% SSH
        function CSVSSH(obj)
            nobj = numel(obj);
            T = JMAtide.CreateReferenceTable;
            
            % % setup
            iobj = 1;
            foutmatrix = [];
            stationlist = '# time, ';
            postfix = '';
            
            % % loop count
            while iobj <= nobj
                % % skip if empty
                if isempty(obj(iobj).time) || isempty(obj(iobj).ssh)
                    disp(['Empty: ', obj(iobj).station])
                    iobj = iobj + 1;
                    continue
                end
                
                % % assign output matrix
                t = obj(iobj).time;
                foutmatrix = horzcat(foutmatrix, obj(iobj).ssh);
                stationlist = horzcat(stationlist, obj(iobj).station,', ');
                row = find(strcmp(obj(iobj).station,T.Name_ja), 1);
                postfix = horzcat(postfix, T.ID{row});
                
                % % filename of output
                fname = ['sealevel_',num2str(obj(iobj).year, '%04d'), ...
                         num2str(obj(iobj).month, '%02d'), ...
                         '_',postfix,'.dat'];
                     
                % % end of list
                if iobj == nobj
                    disp(fname)
                    stationlist(end-1:end) = [];
                    JMAtide.OutputTimeSeries(fname, stationlist, t, foutmatrix)
                    break
                end
                
                % % output if the period is different from the next one
                if obj(iobj).year~=obj(iobj+1).year || obj(iobj).month~=obj(iobj+1).month || ...
                   isempty(obj(iobj+1).time) || isempty(obj(iobj+1).ssh)
                    disp(fname)
                    stationlist(end-1:end) = [];
                    JMAtide.OutputTimeSeries(fname, stationlist, t, foutmatrix)
                    
                    foutmatrix = [];
                    stationlist = '# time, ';
                    postfix = '';
                end
                
                iobj = iobj + 1;
            end
            % % loop end
        end
        
        %% SSHA
        function CSVSSHA(obj)
            nobj = numel(obj);
            T = JMAtide.CreateReferenceTable;
            
            % % setup
            iobj = 1;
            foutmatrix = [];
            stationlist = '# time, ';
            postfix = '';
            
            % % loop count
            while iobj <= nobj
                % % skip if empty
                if isempty(obj(iobj).time) || isempty(obj(iobj).ssha)
                    disp(['Empty: ', obj(iobj).station])
                    iobj = iobj + 1;
                    continue
                end
                
                % % assign output matrix                
                t = obj(iobj).time;
                foutmatrix = horzcat(foutmatrix, obj(iobj).ssha);
                stationlist = horzcat(stationlist, obj(iobj).station,', ');
                row = find(strcmp(obj(iobj).station,T.Name_ja), 1);
                postfix = horzcat(postfix, T.ID{row});
                
                % % filename of output
                fname = ['sealevelanomaly_', num2str(obj(iobj).year, '%04d'), ...
                         num2str(obj(iobj).month, '%02d'), ...
                         '_',postfix,'.dat'];

                % % end of list
                if iobj == nobj
                    disp(fname)
                    stationlist(end-1:end) = [];
                    JMAtide.OutputTimeSeries(fname, stationlist, t, foutmatrix)
                    break
                end
                
                % % output if the period is different from the next one
                if obj(iobj).year~=obj(iobj+1).year || obj(iobj).month~=obj(iobj+1).month || ...
                   isempty(obj(iobj+1).time) || isempty(obj(iobj+1).ssha)
                    disp(fname)
                    stationlist(end-1:end) = [];
                    JMAtide.OutputTimeSeries(fname, stationlist, t, foutmatrix)
                    
                    foutmatrix = [];
                    stationlist = '# time, ';
                    postfix = '';
                end
                
                iobj = iobj + 1;
            end
            % % loop end
        end
        
    end
    
    %% Static methods
    methods (Static)
        %% Table of stations
        function T = CreateReferenceTable
            % % columns
            Number = {1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16;17;18;19;20;21;22;23;24;25;26;27;28;29;30;31;32;33;34;35;36;37;38;39;40;41;42;43;44;45;46;47;48;49;50;51;52;53;54;55;56;57;58;59;60;61;62;63;64;65;66;67;68;69;70};
            ID = {'WN';'AS';'HN';'KR';'HK';'B3';'SH';'MY';'OF';'AY';'ON';'MR';'TK';'OK';'MJ';'CC';'MC';'OD';'G9';'UC';'SM';'OM';'MI';'I4';'NG';'TB';'OW';'KN';'UR';'KS';'SR';'GB';'WY';'TN';'OS';'KB';'ST';'UN';'MT';'TA';'KM';'AW';'MU';'KC';'TS';'UW';'X5';'AB';'KG';'MK';'TJ';'O9';'NH';'DJ';'IS';'YJ';'RH';'OU';'KT';'NS';'FE';'N5';'HA';'SK';'SA';'MZ';'SZ';'TY';'S0';'FK'};
            Name_ja = {'稚内';'網走';'花咲';'釧路';'函館';'小樽';'下北';'宮古';'大船渡';'鮎川';'小名浜';'布良';'東京';'岡田';'三宅島（坪田）';'父島';'南鳥島';'小田原';'石廊崎';'内浦';'清水港';'御前崎';'舞阪';'赤羽根';'名古屋';'鳥羽';'尾鷲';'熊野';'浦神';'串本';'白浜';'御坊';'和歌山';'淡輪';'大阪';'神戸';'洲本';'宇野';'松山';'高松';'小松島';'阿波由岐';'室戸岬';'高知';'土佐清水';'宇和島';'佐伯';'油津';'鹿児島';'枕崎';'種子島';'奄美';'那覇';'南大東';'石垣';'与那国';'苓北';'大浦';'口之津';'長崎';'福江';'対馬比田勝';'浜田';'境';'西郷';'舞鶴';'能登';'富山';'佐渡';'深浦'};
            Address = {'北海道 稚内市 新港町';'北海道 網走市 港町';'北海道 根室市 花咲港';'北海道 釧路市 港町';'北海道 函館市 海岸町';'北海道 小樽市 色内３丁目';'青森県 むつ市 関根';'岩手県 宮古市 日立浜町';'岩手県 大船渡市 赤崎町';'宮城県 石巻市 鮎川浜';'福島県 いわき市 小名浜';'千葉県 館山市 布良';'東京都 中央区 晴海５丁目';'東京都 大島町 岡田';'東京都 三宅村 坪田船戸';'東京都 小笠原村 父島東町';'東京都 小笠原村 南鳥島';'神奈川県 小田原市 早川地先';'静岡県 賀茂郡 南伊豆町 石廊崎';'静岡県 沼津市 内浦長浜網代';'静岡県 静岡市 清水区 三保';'静岡県 御前崎市 港';'静岡県 浜松市 西区 舞阪町';'愛知県 田原市 池尻町';'愛知県 名古屋市 港区 港町';'三重県 鳥羽市 堅神町';'三重県 尾鷲市 天満浦';'三重県 熊野市 遊木町';'和歌山県 東牟婁郡 那智勝浦町 浦神';'和歌山県 東牟婁郡 串本町 串本';'和歌山県 西牟婁郡 白浜町 堅田';'和歌山県 御坊市 名田町';'和歌山県 和歌山市 湊青岸';'大阪府 泉南郡 岬町 淡輪';'大阪府 大阪市 港区 築港３丁目';'兵庫県 神戸市 中央区 波止場町';'兵庫県 洲本市 海岸通１丁目';'岡山県 玉野市 宇野１丁目';'愛媛県 松山市 海岸通';'香川県 高松市 北浜町';'徳島県 小松島市 小松島町';'徳島県 海部郡 美波町 西由岐';'高知県 室戸市 室戸岬町';'高知県 高知市 浦戸';'高知県 土佐清水市 旭町３丁目';'愛媛県 宇和島市 住吉３丁目';'大分県 佐伯市 鶴見';'宮崎県 日南市 大節';'鹿児島県 鹿児島市 本港新町';'鹿児島県 枕崎市 松之尾町';'鹿児島県 熊毛郡 中種子町 坂井';'鹿児島県 奄美市 名瀬小湊';'沖縄県 那覇市 西';'沖縄県 島尻郡 南大東村 北';'沖縄県 石垣市 八島町２丁目';'沖縄県 八重山郡 与那国町 久部良';'熊本県 天草郡 苓北町 都呂々';'佐賀県 藤津郡 太良町 大浦';'長崎県 南島原市 口之津町';'長崎県 長崎市 松が枝町';'長崎県 五島市 東浜町';'長崎県 対馬市 上対馬町';'島根県 浜田市 大辻町';'鳥取県 境港市 境港';'島根県 隠岐郡 隠岐の島町 港町';'京都府 舞鶴市 浜';'石川県 珠洲市 長橋町';'富山県 富山市 草島';'新潟県 佐渡市 鷲崎';'青森県 西津軽郡 深浦町 深浦'};
            Latitude = {45.4000000000000;44.0166666666667;43.2833333333333;42.9833333333333;41.7833333333333;43.2000000000000;41.3666666666667;39.6500000000000;39.0166666666667;38.3000000000000;36.9333333333333;34.9166666666667;35.6500000000000;34.7833333333333;34.0500000000000;27.1000000000000;24.2833333333333;35.2333333333333;34.6166666666667;35.0166666666667;35.0166666666667;34.6166666666667;34.6833333333333;34.6000000000000;35.0833333333333;34.4833333333333;34.0833333333333;33.9333333333333;33.5666666666667;33.4833333333333;33.6833333333333;33.8500000000000;34.2166666666667;34.3333333333333;34.6500000000000;34.6833333333333;34.3500000000000;34.4833333333333;33.8666666666667;34.3500000000000;34.0166666666667;33.7666666666667;33.2666666666667;33.5000000000000;32.7833333333333;33.2333333333333;32.9500000000000;31.5833333333333;31.6000000000000;31.2666666666667;30.4666666666667;28.3166666666667;26.2166666666667;25.8666666666667;24.3333333333333;24.4500000000000;32.4666666666667;32.9833333333333;32.6000000000000;32.7333333333333;32.7000000000000;34.6500000000000;34.9000000000000;35.5500000000000;36.2000000000000;35.4833333333333;37.5000000000000;36.7666666666667;38.3166666666667;40.6500000000000};
            Longitude = {141.683333333333;144.283333333333;145.566666666667;144.366666666667;140.716666666667;141;141.233333333333;141.983333333333;141.750000000000;141.500000000000;140.900000000000;139.833333333333;139.766666666667;139.383333333333;139.550000000000;142.200000000000;153.983333333333;139.150000000000;138.850000000000;138.883333333333;138.516666666667;138.216666666667;137.616666666667;137.183333333333;136.883333333333;136.816666666667;136.200000000000;136.166666666667;135.900000000000;135.766666666667;135.383333333333;135.166666666667;135.150000000000;135.183333333333;135.433333333333;135.183333333333;134.900000000000;133.950000000000;132.716666666667;134.050000000000;134.583333333333;134.600000000000;134.166666666667;133.566666666667;132.966666666667;132.550000000000;131.966666666667;131.416666666667;130.566666666667;130.300000000000;130.966666666667;129.533333333333;127.666666666667;131.233333333333;124.166666666667;122.950000000000;130.033333333333;130.216666666667;130.200000000000;129.866666666667;128.850000000000;129.483333333333;132.066666666667;133.250000000000;133.333333333333;135.383333333333;137.150000000000;137.216666666667;138.516666666667;139.933333333333};
            Type = {'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'水圧式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式'};
            Height_above_the_reference_plane = {374.500000000000;440.700000000000;485.900000000000;397.800000000000;360.600000000000;561.100000000000;691.400000000000;467.900000000000;532.900000000000;571;563.700000000000;667.100000000000;530.200000000000;484.800000000000;741;414.300000000000;NaN;850;643.800000000000;360.200000000000;388.700000000000;424;567.500000000000;726.600000000000;719.500000000000;637.100000000000;743.300000000000;918.400000000000;472;555.200000000000;650;816.200000000000;447.800000000000;475.400000000000;817.400000000000;491.400000000000;550;516.800000000000;606.300000000000;582.100000000000;400;768.900000000000;800;588.100000000000;584.600000000000;595.700000000000;800;664.300000000000;613.600000000000;680;701.900000000000;531.900000000000;545.300000000000;1020.80000000000;675;820.200000000000;1300;935.400000000000;706.500000000000;550;650;526.400000000000;324.200000000000;329.900000000000;369;450;537.800000000000;390;432.800000000000;519.400000000000};
            Elevation = {208.900000000000;290.200000000000;272.500000000000;205.800000000000;204.300000000000;350.200000000000;426;339.700000000000;277;310.100000000000;391.300000000000;529;341.800000000000;330.600000000000;324.500000000000;228.300000000000;NaN;505.100000000000;268.200000000000;208.100000000000;233.700000000000;233;332.100000000000;367.500000000000;519.100000000000;355.400000000000;596;680.300000000000;333.400000000000;394.100000000000;335.800000000000;550.200000000000;356.100000000000;292.300000000000;462.400000000000;323.200000000000;364.400000000000;342.300000000000;391.600000000000;392.300000000000;208.500000000000;504.700000000000;507.400000000000;492.200000000000;428.500000000000;387.900000000000;347.100000000000;523;419;434.200000000000;326.300000000000;312.900000000000;287.300000000000;462.300000000000;502.600000000000;446.200000000000;887.900000000000;563.900000000000;366.900000000000;275.700000000000;386.200000000000;334.300000000000;232.900000000000;214.300000000000;262.400000000000;317.900000000000;416;281.300000000000;281.800000000000;389.600000000000};
            Elevation_of_the_reference_plane = {-165.600000000000;-150.500000000000;-213.400000000000;-192;-156.300000000000;-210.900000000000;-265.400000000000;-128.200000000000;-255.900000000000;-260.900000000000;-172.400000000000;-138.100000000000;-188.400000000000;-154.200000000000;-416.500000000000;-186;-196.100000000000;-344.900000000000;-375.600000000000;-152.100000000000;-155;-191;-235.400000000000;-359.100000000000;-200.400000000000;-281.700000000000;-147.300000000000;-238.100000000000;-138.600000000000;-161.100000000000;-314.200000000000;-266;-91.7000000000000;-183.100000000000;-355;-168.200000000000;-185.600000000000;-174.500000000000;-214.700000000000;-189.800000000000;-191.500000000000;-264.200000000000;-292.600000000000;-95.9000000000000;-156.100000000000;-207.800000000000;-452.900000000000;-141.300000000000;-194.600000000000;-245.800000000000;-375.600000000000;-219;-258;-558.500000000000;-172.400000000000;-374;-412.100000000000;-371.500000000000;-339.600000000000;-274.300000000000;-263.800000000000;-192.100000000000;-91.3000000000000;-115.600000000000;-106.600000000000;-132.100000000000;-121.800000000000;-108.700000000000;-151;-129.800000000000};
            Note = {[];[];[];[];'*1';[];[];'*1';[];[];[];[];[];[];[];[];'*2';[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];'*1';[];[];'*1';[];[];[];[];[];[];[];'*1';[];'*1';[];[];[];[];[];[];[];[];[];[];[];[];[]};
            % % create a table
            T = table(Number,ID,Name_ja,Address,Latitude,Longitude,Type,Height_above_the_reference_plane,Elevation,Elevation_of_the_reference_plane,Note);
            return
        end
        
        %% Output time-series data 
        function OutputTimeSeries(fname, stationlist, t, foutmatrix)
            if isempty(foutmatrix); return; end
            
            [nrow, ncol] = size(foutmatrix);
            if ncol == 1
                fmt = '%9.3f\n';
            else
                fmt = [repmat('%9.3f,',[1, ncol-1]),'%9.3f\n'];
            end
            
            fid = fopen(fname,'w');
            fprintf(fid, '%s\n', stationlist);
            for line = 1:nrow
                fprintf(fid, '%s', datestr(t(line),'YYYYmmddThhMM,'));
                fprintf(fid, fmt, foutmatrix(line,:));
            end
            fclose(fid);
        end

    end
end