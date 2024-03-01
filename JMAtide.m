classdef JMAtide
    %% Properties
    properties
        Station
        Year
        Month
        Time
        Ndays
        SSH   % sea surface height
        SSHanomaly  % sea surface height anomaly
        AstronomicalTide % (Estimated) astronomical tide
        Lon
        Lat
        URL_ssh
        URL_ssha
        URL_astro
        RefLevelObs_TP_cm
        RefLevelAst_TP_cm
        Unit = 'cm'
    end
    
    %% Properties as constant values
    properties (Constant)
        StandardTime = 'JST(UTC+9)'
        ReferenceLevel = 'T.P.'
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
                        obj(i,j).Station = stationname{i};
                        obj(i,j).Year = year(j);
                        obj(i,j).Month = month(j);
                    end
                end
                
                % % file URL
                obj = obj.setproperty;
            end            
        end
    end
    
    %% Methods for data processing
    methods
        %% set properties
        function obj = setproperty(obj)
            urlbase_obs = 'https://www.data.jma.go.jp/gmd/kaiyou/data/db/tide/genbo/YYYY/YYYYMM/hryYYYYMMSTATION.txt';
            Tobs = JMAtide.createReferenceTableForObs;
            urlbase_astro = 'https://www.data.jma.go.jp/kaiyou/data/db/tide/suisan/txt/YYYY/STATION.txt';
            Tastro = JMAtide.createReferenceTableForAstro;            
            for i = 1:numel(obj)
                % % url 
                url1 = urlbase_obs;
                url1 = strrep(url1, 'MM', num2str(obj(i).Month,'%02d'));
                url1 = strrep(url1, 'YYYY', num2str(obj(i).Year,'%04d'));
                row = find(strcmp(obj(i).Station,Tobs.Name_ja), 1);
                if ~isempty(row)
                    url1 = strrep(url1, 'STATION', Tobs.ID{row});
                    url2 = strrep(url1, 'hry', 'dep');
                    obj(i).URL_ssh = url1;
                    obj(i).URL_ssha = url2;
                    obj(i).Lon = Tobs.Longitude(row);
                    obj(i).Lat = Tobs.Latitude(row);
                    obj(i).RefLevelObs_TP_cm = Tobs.RefLevel_TP(row);
                end

                url3 = urlbase_astro;
                url3 = strrep(url3, 'YYYY', num2str(obj(i).Year,'%04d'));
                row = find(strcmp(obj(i).Station,Tastro.Name_ja), 1);
                if ~isempty(row)
                    url3 = strrep(url3, 'STATION', Tastro.ID{row});
                    obj(i).URL_astro = url3;
                    obj(i).Lon = Tastro.Longitude(row);
                    obj(i).Lat = Tastro.Latitude(row);
                    obj(i).RefLevelAst_TP_cm = Tastro.RefLevel_TP(row);
                end

                if isempty(obj(i).URL_ssh) && isempty(obj(i).URL_astro)
                    disp(['Station name ', obj(i).Station,' was not found.'])
                end

            end                            
        end
        
        %% read sea surface height (SSH) from URL
        function obj = loadssh(obj)
            % % array
            if numel(obj)>1
                for i = 1:numel(obj)
                    obj(i) = obj(i).loadssh;
                end
                return
            end
            
            % % scalar
            % % read from the original source
            txt = webread(obj.URL_ssh);
            
            % % calc the number of the day in month
            obj.Ndays = length(txt)/137;
            
            % % % assign time series
            obj.Time = permute(datetime(obj.Year, obj.Month, 1):hours(1):datetime(obj.Year, obj.Month, obj.Ndays, 23, 0, 0), [2,1]);
                        
            % % assign SSH
            dat = cell(obj.Ndays,24);
            for i = 1:obj.Ndays
                for j = 1:24
                    dat{i,j} = txt((i-1)*137+(j-1)*3+1:(i-1)*137+j*3);
                end
            end
            
            % % convert
            dat = cellfun(@strtrim, dat, 'UniformOutput', false);
            dat = cell2mat(cellfun(@str2double, dat, 'UniformOutput', false))';
            dat = dat + obj.RefLevelObs_TP_cm;
            if strcmp(obj.Unit,'m')
                factor = 0.01;
            else
                factor = 1.0;
            end
            obj.SSH = factor*dat(:);
        end
        
        %% read sea surface height anomaly (SSHA) from URL
        function obj = loadssha(obj)
            % % array
            if numel(obj)>1
                for i = 1:numel(obj)
                    obj(i) = obj(i).loadssha;
                end
                return
            end
            
            % % scalar            
            % % read from the original source
            txt = webread(obj.URL_ssha);

            % % calc the number of the day in month
            obj.Ndays = length(txt)/107;

            % % assign time series
            obj.Time = (datetime(obj.Year, obj.Month, 1):hours(1):datetime(obj.Year, obj.Month, obj.Ndays, 23, 0, 0))';
            
            % % assign SSHA
            dat = cell(obj.Ndays,24);
            for i = 1:obj.Ndays
                for j = 1:24
                    dat{i,j} = txt((i-1)*107+(j-1)*4+1:(i-1)*107+j*4);
                end
            end
            
            % % convert
            dat = cellfun(@strtrim, dat, 'UniformOutput', false);
            dat = cell2mat(cellfun(@str2double, dat, 'UniformOutput', false))';
            if strcmp(obj.Unit,'m')
                factor = 0.01;
            else
                factor = 1.0;
            end
            obj.SSHanomaly = factor*dat(:);
        end

        %% read estimated astronomical tides from URL
        function obj = loadastronimocaltide(obj)
            % % array
            if numel(obj)>1
                for i = 1:numel(obj)
                    obj(i) = obj(i).loadastronimocaltide;
                end
                return
            end

            % % read and rearrange
            ntxt_line = 137;
            txt = webread(obj.URL_astro);
            L = length(txt);
            nline = L/ntxt_line;
            txt = reshape(txt,[ntxt_line,nline])';
            txt(:,end) = [];

            % % time set
            date_begin = datetime(...
                str2double(['20',txt(1,73:74)]),  ...
                str2double(strtrim(txt(1,75:76))), ...
                str2double(strtrim(txt(1,77:78))), ...
                0,0,0,0);
            date_end = datetime(...
                str2double(['20',txt(end,73:74)]), ...
                str2double(strtrim(txt(end,75:76))), ...
                str2double(strtrim(txt(end,77:78))), ...
                23,0,0,0);
            ttide = (date_begin:hours(1):date_end)';
            nttide = length(ttide);

            %% parse tide
            txt_tide = reshape(txt(:,1:72)',[3,nttide])';
            tide = zeros(nttide,1);
            for i = 1:nttide
                tide(i) = str2double(strtrim(txt_tide(i,:)));
            end

            obj.Ndays = double(days(datetime(obj.Year, obj.Month+1, 1)-datetime(obj.Year, obj.Month, 1)));
            obj.Time = (datetime(obj.Year, obj.Month, 1):hours(1):datetime(obj.Year, obj.Month, obj.Ndays, 23, 0, 0))';

            dat = interp1(ttide,tide,obj.Time);
            dat = dat + obj.RefLevelAst_TP_cm;
            if strcmp(obj.Unit,'m')
                factor = 0.01;
            else
                factor = 1.0;
            end            
            obj.AstronomicalTide = factor*dat;
        end
        
        %% Convert Unit
        function obj = convertunit(obj, unitstr)
            % % check arguments
            if ~ischar(unitstr); error('Unit specification must be "cm" or "m".'); end
            if ~strcmp(unitstr,'cm') && ~strcmp(unitstr,'m'); error('Unit specification must be "cm" or "m".'); end
            
            % % if object array
            if numel(obj)>1
                for i = 1:numel(obj)
                    obj(i) = obj(i).convertunit(unitstr);
                end
                return
            end
            
            % % check
            if strcmp(unitstr,obj.Unit)
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
            if ~isempty(obj.SSH) ; obj.SSH  = factor*obj.SSH; end
            if ~isempty(obj.SSHanomaly); obj.SSHanomaly = factor*obj.SSHanomaly; end
            if ~isempty(obj.AstronomicalTide); obj.AstronomicalTide = factor*obj.AstronomicalTide; end
            obj.Unit = unitstr;
        end


        %% get estimated astronimical tidal level
        function tidelevel = getastronomicaltide(obj,time)
            if numel(obj)>1; error('Object array is currently not supported.'); end
            if isempty(obj.AstronomicalTide); error('Please load tidal level via obj = obj.loadastoronomicaltide() before doing this.'); end
            if ~isdatetime(time); error('time must be a type of datetime.'); end
            nq = numel(time);
            tidelevel = NaN*zeros(nq,1);
            for i = 1:nq
                if min(abs(hours((obj.Time-time(i)))))>1; continue; end
                tidelevel(i) = interp1(obj.Time, obj.AstronomicalTide, time(i),'linear','extrap');
            end
            return
        end
    end

    %% Methods for plotting
    methods        
        %% Plot SSH
        function line = plotssh(obj)
            % % array
            if numel(obj)>1
                for i = 1:numel(obj)
                    if isempty(obj(i).SSH); continue; end
                    line(i) = obj(i).plotssh;
                    hold on
                end
                hold off
                return
            end            
            % % scalar
            line = plot(obj.Time, obj.SSH);
        end    
        
        %% Plot SSHA
        function line = plotssha(obj)
            % % array
            if numel(obj)>1
                for i = 1:numel(obj)
                    if isempty(obj(i).SSHanomaly); continue; end
                    line(i) = obj(i).plotssha;
                    hold on
                end
                hold off
                return
            end            
            % % scalar
            line = plot(obj.Time, obj.SSHanomaly);
        end        
        %% Plot astronomical tide
        function line = plotastronomicaltide(obj)
            % % array
            if numel(obj)>1
                for i = 1:numel(obj)
                    if isempty(obj(i).AstronomicalTide); continue; end
                    line(i) = obj(i).plotastronomicaltide;
                    hold on
                end
                hold off
                return
            end            
            % % scalar
            line = plot(obj.Time, obj.AstronomicalTide);
        end        
    end
    
    %% Methods for output
    methods
        %% SSH
        function csvssh(obj)
            nobj = numel(obj);
            T = JMAtide.createReferenceTableForObs;
            
            % % setup
            iobj = 1;
            foutmatrix = [];
            stationlist = '# time, ';
            postfix = '';
            
            % % loop count
            while iobj <= nobj
                % % skip if empty
                if isempty(obj(iobj).Time) || isempty(obj(iobj).SSH)
                    disp(['Empty: ', obj(iobj).Station])
                    iobj = iobj + 1;
                    continue
                end
                
                % % assign output matrix
                t = obj(iobj).Time;
                foutmatrix = horzcat(foutmatrix, obj(iobj).SSH);
                stationlist = horzcat(stationlist, obj(iobj).Station,', ');
                row = find(strcmp(obj(iobj).Station,T.Name_ja), 1);
                postfix = horzcat(postfix, T.ID{row});
                
                % % filename of output
                fname = ['sealevel_',num2str(obj(iobj).Year, '%04d'), ...
                         num2str(obj(iobj).Month, '%02d'), ...
                         '_',postfix,'.dat'];
                     
                % % end of list
                if iobj == nobj
                    disp(fname)
                    stationlist(end-1:end) = [];
                    JMAtide.outputTimeSeries(fname, stationlist, t, foutmatrix)
                    break
                end
                
                % % output if the period is different from the next one
                if obj(iobj).Year~=obj(iobj+1).Year || obj(iobj).Month~=obj(iobj+1).Month || ...
                   isempty(obj(iobj+1).Time) || isempty(obj(iobj+1).SSH)
                    disp(fname)
                    stationlist(end-1:end) = [];
                    JMAtide.outputTimeSeries(fname, stationlist, t, foutmatrix)
                    
                    foutmatrix = [];
                    stationlist = '# time, ';
                    postfix = '';
                end
                
                iobj = iobj + 1;
            end
            % % loop end
        end
        
        %% SSHA
        function csvssha(obj)
            nobj = numel(obj);
            T = JMAtide.createReferenceTableForObs;
            
            % % setup
            iobj = 1;
            foutmatrix = [];
            stationlist = '# time, ';
            postfix = '';
            
            % % loop count
            while iobj <= nobj
                % % skip if empty
                if isempty(obj(iobj).Time) || isempty(obj(iobj).SSHanomaly)
                    disp(['Empty: ', obj(iobj).Station])
                    iobj = iobj + 1;
                    continue
                end
                
                % % assign output matrix                
                t = obj(iobj).Time;
                foutmatrix = horzcat(foutmatrix, obj(iobj).SSHanomaly);
                stationlist = horzcat(stationlist, obj(iobj).Station,', ');
                row = find(strcmp(obj(iobj).Station,T.Name_ja), 1);
                postfix = horzcat(postfix, T.ID{row});
                
                % % filename of output
                fname = ['sealevelanomaly_', num2str(obj(iobj).Year, '%04d'), ...
                         num2str(obj(iobj).Month, '%02d'), ...
                         '_',postfix,'.dat'];

                % % end of list
                if iobj == nobj
                    disp(fname)
                    stationlist(end-1:end) = [];
                    JMAtide.outputTimeSeries(fname, stationlist, t, foutmatrix)
                    break
                end
                
                % % output if the period is different from the next one
                if obj(iobj).Year~=obj(iobj+1).Year || obj(iobj).Month~=obj(iobj+1).Month || ...
                   isempty(obj(iobj+1).Time) || isempty(obj(iobj+1).SSHanomaly)
                    disp(fname)
                    stationlist(end-1:end) = [];
                    JMAtide.outputTimeSeries(fname, stationlist, t, foutmatrix)
                    
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
        %% Table of stations for observed data
        function T = createReferenceTableForObs
            % % columns
            Number = {1;2;3;4;5;6;7;8;9;10;11;12;13;14;15;16;17;18;19;20;21;22;23;24;25;26;27;28;29;30;31;32;33;34;35;36;37;38;39;40;41;42;43;44;45;46;47;48;49;50;51;52;53;54;55;56;57;58;59;60;61;62;63;64;65;66;67;68;69;70};
            ID = {'WN';'AS';'HN';'KR';'HK';'B3';'SH';'MY';'OF';'AY';'ON';'MR';'TK';'OK';'MJ';'CC';'MC';'OD';'G9';'UC';'SM';'OM';'MI';'I4';'NG';'TB';'OW';'KN';'UR';'KS';'SR';'GB';'WY';'TN';'OS';'KB';'ST';'UN';'MT';'TA';'KM';'AW';'MU';'KC';'TS';'UW';'X5';'AB';'KG';'MK';'TJ';'O9';'NH';'DJ';'IS';'YJ';'RH';'OU';'KT';'NS';'FE';'N5';'HA';'SK';'SA';'MZ';'SZ';'TY';'S0';'FK'};
            Name_ja = {'稚内';'網走';'花咲';'釧路';'函館';'小樽';'下北';'宮古';'大船渡';'鮎川';'小名浜';'布良';'東京';'岡田';'三宅島（坪田）';'父島';'南鳥島';'小田原';'石廊崎';'内浦';'清水港';'御前崎';'舞阪';'赤羽根';'名古屋';'鳥羽';'尾鷲';'熊野';'浦神';'串本';'白浜';'御坊';'和歌山';'淡輪';'大阪';'神戸';'洲本';'宇野';'松山';'高松';'小松島';'阿波由岐';'室戸岬';'高知';'土佐清水';'宇和島';'佐伯';'油津';'鹿児島';'枕崎';'種子島';'奄美';'那覇';'南大東';'石垣';'与那国';'苓北';'大浦';'口之津';'長崎';'福江';'対馬比田勝';'浜田';'境';'西郷';'舞鶴';'能登';'富山';'佐渡';'深浦'};
            Address = {'北海道 稚内市 新港町';'北海道 網走市 港町';'北海道 根室市 花咲港';'北海道 釧路市 港町';'北海道 函館市 海岸町';'北海道 小樽市 色内３丁目';'青森県 むつ市 関根';'岩手県 宮古市 日立浜町';'岩手県 大船渡市 赤崎町';'宮城県 石巻市 鮎川浜';'福島県 いわき市 小名浜';'千葉県 館山市 布良';'東京都 中央区 晴海５丁目';'東京都 大島町 岡田';'東京都 三宅村 坪田船戸';'東京都 小笠原村 父島東町';'東京都 小笠原村 南鳥島';'神奈川県 小田原市 早川地先';'静岡県 賀茂郡 南伊豆町 石廊崎';'静岡県 沼津市 内浦長浜網代';'静岡県 静岡市 清水区 三保';'静岡県 御前崎市 港';'静岡県 浜松市 西区 舞阪町';'愛知県 田原市 池尻町';'愛知県 名古屋市 港区 港町';'三重県 鳥羽市 堅神町';'三重県 尾鷲市 天満浦';'三重県 熊野市 遊木町';'和歌山県 東牟婁郡 那智勝浦町 浦神';'和歌山県 東牟婁郡 串本町 串本';'和歌山県 西牟婁郡 白浜町 堅田';'和歌山県 御坊市 名田町';'和歌山県 和歌山市 湊青岸';'大阪府 泉南郡 岬町 淡輪';'大阪府 大阪市 港区 築港３丁目';'兵庫県 神戸市 中央区 波止場町';'兵庫県 洲本市 海岸通１丁目';'岡山県 玉野市 宇野１丁目';'愛媛県 松山市 海岸通';'香川県 高松市 北浜町';'徳島県 小松島市 小松島町';'徳島県 海部郡 美波町 西由岐';'高知県 室戸市 室戸岬町';'高知県 高知市 浦戸';'高知県 土佐清水市 旭町３丁目';'愛媛県 宇和島市 住吉３丁目';'大分県 佐伯市 鶴見';'宮崎県 日南市 大節';'鹿児島県 鹿児島市 本港新町';'鹿児島県 枕崎市 松之尾町';'鹿児島県 熊毛郡 中種子町 坂井';'鹿児島県 奄美市 名瀬小湊';'沖縄県 那覇市 西';'沖縄県 島尻郡 南大東村 北';'沖縄県 石垣市 八島町２丁目';'沖縄県 八重山郡 与那国町 久部良';'熊本県 天草郡 苓北町 都呂々';'佐賀県 藤津郡 太良町 大浦';'長崎県 南島原市 口之津町';'長崎県 長崎市 松が枝町';'長崎県 五島市 東浜町';'長崎県 対馬市 上対馬町';'島根県 浜田市 大辻町';'鳥取県 境港市 境港';'島根県 隠岐郡 隠岐の島町 港町';'京都府 舞鶴市 浜';'石川県 珠洲市 長橋町';'富山県 富山市 草島';'新潟県 佐渡市 鷲崎';'青森県 西津軽郡 深浦町 深浦'};
            Latitude = [45.400;44.01667;43.2833;42.9833;41.7833;43.200;41.36667;39.650;39.01667;38.300;36.9333;34.91667;35.650;34.7833;34.050;27.100;24.2833;35.2333;34.61667;35.01667;35.01667;34.61667;34.6833;34.600;35.0833;34.4833;34.0833;33.9333;33.56667;33.4833;33.6833;33.850;34.21667;34.3333;34.650;34.6833;34.350;34.4833;33.86667;34.350;34.01667;33.76667;33.26667;33.500;32.7833;33.2333;32.950;31.5833;31.600;31.26667;30.46667;28.31667;26.21667;25.86667;24.3333;24.450;32.46667;32.9833;32.600;32.7333;32.700;34.650;34.900;35.550;36.200;35.4833;37.500;36.76667;38.31667;40.650];
            Longitude = [141.6833;144.2833;145.5667;144.3667;140.7167;141;141.233;141.9833;141.7500;141.50;140.90;139.833;139.7667;139.3833;139.5500;142.20;153.9833;139.1500;138.8500;138.8833;138.5167;138.2167;137.6167;137.1833;136.8833;136.8167;136.20;136.1667;135.90;135.7667;135.3833;135.1667;135.1500;135.1833;135.433;135.1833;134.90;133.9500;132.7167;134.0500;134.5833;134.60;134.1667;133.5667;132.9667;132.5500;131.9667;131.4167;130.5667;130.30;130.9667;129.533;127.6667;131.233;124.1667;122.9500;130.033;130.2167;130.20;129.8667;128.8500;129.4833;132.0667;133.2500;133.333;135.3833;137.1500;137.2167;138.5167;139.933];
            Type = ['電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'水圧式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式';'電波式'];
            RefLevel_TP = [-165.0;-150.5;-213.40;-192;-156.30;-210.90;-265.40;-128.20;-255.90;-260.90;-172.40;-138.10;-188.40;-154.20;-416.50;-186;-196.10;-344.90;-375.60;-152.10;-155;-191;-235.40;-359.10;-200.40;-281.70;-147.30;-238.10;-138.60;-161.10;-314.20;-266;-91.700;-183.10;-355;-168.20;-185.60;-174.50;-214.70;-189.80;-191.50;-264.20;-292.60;-95.900;-156.10;-207.80;-452.90;-141.30;-194.60;-245.80;-375.60;-219;-258;-558.50;-172.40;-374;-412.10;-371.50;-339.60;-274.30;-263.80;-192.10;-91.300;-115.60;-106.60;-132.10;-121.80;-108.70;-151;-129.80];
            Note = {[];[];[];[];'*1';[];[];'*1';[];[];[];[];[];[];[];[];'*2';[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];[];'*1';[];[];'*1';[];[];[];[];[];[];[];'*1';[];'*1';[];[];[];[];[];[];[];[];[];[];[];[];[]};
            % % create a table
            T = table(Number,ID,Name_ja,Address,Latitude,Longitude,Type,RefLevel_TP,Note);
            return
        end
        %% Table of stations for astronomical tides
        function T = createReferenceTableForAstro
            Number = {'1';'4';'7';'9';'17';'21';'26';'27';'31';'33';'36';'40';'41';'42';'43';'47';'48';'53';'54';'57';'59';'62';'64';'65';'66';'67';'68';'69';'71';'72';'73';'75';'76';'79';'80';'81';'82';'83';'84';'85';'86';'90';'91';'93';'94';'95';'96';'97';'98';'99';'101';'102';'103';'108';'111';'113';'117';'122';'123';'124';'132';'142';'143';'145';'148';'149';'151';'153';'155';'162';'163';'164';'166';'168';'169';'170';'171';'172';'173';'174';'175';'176';'178';'179';'180';'182';'184';'188';'192';'193';'194';'196';'197';'199';'201';'203';'205';'207';'208';'209';'210';'211';'214';'216';'218';'219';'223';'226';'229';'231';'232';'233';'235';'238';'239'};
            ID = {'WN';'AS';'HN';'KR';'HK';'ZP';'Z8';'B3';'Q1';'ZA';'SH';'MY';'Q6';'OF';'AY';'ZM';'ON';'ZF';'MR';'QL';'TK';'QS';'QN';'Z1';'OK';'QO';'MJ';'QP';'QQ';'CC';'MC';'OD';'Z3';'G9';'Z4';'UC';'SM';'Z5';'OM';'MI';'I4';'ZD';'NG';'TB';'OW';'KN';'UR';'KS';'SR';'GB';'Z9';'WY';'TN';'OS';'KB';'ST';'UN';'Q9';'Q8';'QA';'MT';'TA';'KM';'AW';'MU';'KC';'ZH';'TS';'UW';'QC';'X5';'Z6';'AB';'QG';'KG';'MK';'ZJ';'QH';'TJ';'QI';'QJ';'O9';'ZO';'NH';'DJ';'IS';'YJ';'RH';'OU';'KT';'NS';'FE';'QD';'ZL';'QF';'QE';'N5';'ZK';'HA';'SK';'SA';'ZE';'MZ';'ZG';'Z7';'SZ';'TY';'ZC';'ZN';'S0';'QR';'ZB';'ZQ';'ZI';'FK'};
            Name_ja = {'稚内';'網走';'花咲';'釧路';'函館';'奥尻';'忍路';'小樽';'竜飛';'浅虫';'下北';'宮古';'釜石';'大船渡';'鮎川';'相馬';'小名浜';'勝浦';'布良';'千葉';'東京';'横浜';'横須賀';'油壺';'岡田';'神津島';'三宅島（坪田）';'三宅島（阿古）';'八丈島（神湊）';'父島';'南鳥島';'小田原';'伊東';'石廊崎';'田子';'内浦';'清水港';'焼津';'御前崎';'舞阪';'赤羽根';'鬼崎';'名古屋';'鳥羽';'尾鷲';'熊野';'浦神';'串本';'白浜';'御坊';'海南';'和歌山';'淡輪';'大阪';'神戸';'洲本';'宇野';'呉';'広島';'徳山';'松山';'高松';'小松島';'阿波由岐';'室戸岬';'高知';'久礼';'土佐清水';'宇和島';'大分';'佐伯';'細島';'油津';'大泊';'鹿児島';'枕崎';'阿久根';'西之表';'種子島';'中之島';'名瀬';'奄美';'沖縄';'那覇';'南大東';'石垣';'与那国';'苓北';'大浦';'口之津';'長崎';'福江';'佐世保';'仮屋';'博多';'厳原';'対馬比田勝';'須佐';'浜田';'境';'西郷';'田後';'舞鶴';'三国';'輪島';'能登';'富山';'柏崎';'小木';'佐渡';'粟島';'鼠ヶ関';'飛島';'男鹿';'深浦'};
            Latitude = [45.400;44.01667;43.2833;42.9833;41.7833;42.0833;43.21667;43.200;41.250;40.900;41.36667;39.650;39.26667;39.01667;38.300;37.8333;36.9333;35.1333;34.91667;35.56667;35.650;35.450;35.2833;35.16667;34.7833;34.21667;34.050;34.06667;33.1333;27.100;24.2833;35.2333;34.900;34.61667;34.800;35.01667;35.01667;34.86667;34.61667;34.6833;34.600;34.900;35.0833;34.4833;34.0833;33.9333;33.56667;33.4833;33.6833;33.850;34.150;34.21667;34.3333;34.650;34.6833;34.350;34.4833;34.2333;34.350;34.0333;33.86667;34.350;34.01667;33.76667;33.26667;33.500;33.3333;32.7833;33.2333;33.26667;32.950;32.4333;31.5833;31.01667;31.600;31.26667;32.01667;30.7333;30.46667;29.850;28.400;28.31667;26.1833;26.21667;25.86667;24.3333;24.450;32.46667;32.9833;32.600;32.7333;32.700;33.150;33.46667;33.61667;34.200;34.650;34.6333;34.900;35.550;36.200;35.600;35.4833;36.250;37.400;37.500;36.76667;37.350;37.81667;38.31667;38.46667;38.56667;39.1833;39.950;40.650];
            Longitude = [141.6833;144.2833;145.5667;144.3667;140.7167;139.4833;140.8667;141;140.3833;140.8667;141.233;141.9833;141.8833;141.7500;141.50;140.9667;140.90;140.2500;139.833;140.0500;139.7667;139.6500;139.6500;139.6167;139.3833;139.133;139.5500;139.4833;139.80;142.20;153.9833;139.1500;139.133;138.8500;138.7667;138.8833;138.5167;138.333;138.2167;137.6167;137.1833;136.8167;136.8833;136.8167;136.20;136.1667;135.90;135.7667;135.3833;135.1667;135.20;135.1500;135.1833;135.433;135.1833;134.90;133.9500;132.5500;132.4667;131.80;132.7167;134.0500;134.5833;134.60;134.1667;133.5667;133.2500;132.9667;132.5500;131.6833;131.9667;131.6667;131.4167;130.6833;130.5667;130.30;130.1833;131;130.9667;129.8500;129.50;129.533;127.8167;127.6667;131.233;124.1667;122.9500;130.033;130.2167;130.20;129.8667;128.8500;129.7167;129.8500;130.40;129.30;129.4833;131.60;132.0667;133.2500;133.333;134.3167;135.3833;136.1500;136.90;137.1500;137.2167;138.5167;138.2833;138.5167;139.2500;139.5500;139.5500;139.70;139.933];
            MSL_RefLevel = [18;68;86;87;57;19;17;16;33;37;80;83;86;88;88;88;84;90;90;120;120;115;110;93;90;97;91;91;81;68;35;95;98;100;100;100;95;95;100;70;105;130;140;120;104;102;105;105;110;110;111;111;95;95;95;95;140;200;200;180;190;140;101;106;110;108;111;112;130;130;105;106;116;142;155;150;160;120;120;125;115;119;120;118;98;107;100;166;268;194;164;159;165;127;110;93;58;40;29;17;17;20;19;18;20;20;22;21;19;18;20;20;19;18;18];
            MSL_TP = [16.800;-1.5000;5.1000;-3.4000;-15.900;23.800;8.8000;14.200;9.6000;13.500;2.3000;-4.1000;-11.800;-18.600;-32.700;-13;-15.300;-6.4000;8.7000;7.4000;5;4.3000;7.6000;4.7000;4.7000;NaN;20.100;31.300;24.500;9.1000;4.6000;0.40000;9.7000;16.700;23.400;17.800;27.800;29;16.900;14.100;3.9000;5.8000;11;7.9000;11.900;15.600;26.600;31.700;15.500;14.300;11.900;16.200;14.800;20.200;22.400;21.800;21;20.700;23.100;20;13.800;17.800;17.100;17.200;31.400;12.900;11.900;25.800;15.700;15.900;13.900;17.900;21.400;18.100;22.500;25.100;26.600;10.700;5.4000;11.600;10.200;9;7.1000;7.6000;33.200;15.900;5.3000;22;25.400;24;26.200;10;26.100;25.100;28.700;9.6000;11.100;27.300;29.900;32.300;14.200;31.700;30.100;35.500;25;25.600;32.700;21.800;-0.50000;4.6000;11;31.200;1.7000;27.900;29.200];
            RefLevel_TP = [-1.2000;-69.500;-80.900;-90.400;-72.900;4.8000;-8.2000;-1.8000;-23.400;-23.500;-77.700;-87.100;-97.800;-106.60;-120.70;-101;-99.300;-96.400;-81.300;-112.60;-115;-110.70;-102.40;-88.300;-85.300;-97;-70.900;-59.700;-56.500;-58.900;-30.400;-94.600;-88.300;-83.300;-76.600;-82.200;-67.200;-66;-83.100;-55.900;-101.10;-124.20;-129;-112.10;-92.100;-86.400;-78.400;-73.300;-94.500;-95.700;-99.100;-94.800;-80.200;-74.800;-72.600;-73.200;-119;-179.30;-176.90;-160;-176.20;-122.20;-83.900;-88.800;-78.600;-95.100;-99.100;-86.200;-114.30;-114.10;-91.100;-88.100;-94.600;-123.90;-132.50;-124.90;-133.40;-109.30;-114.60;-113.40;-104.80;-110;-112.90;-110.40;-64.800;-91.100;-94.700;-144;-242.60;-170;-137.80;-149;-138.90;-101.90;-81.300;-83.400;-46.900;-12.700;0.90000;15.300;-2.8000;11.700;11.100;17.500;5;5.6000;10.700;0.80000;-19.500;-13.400;-9;11.200;-17.300;9.9000;11.200];
            % % create a table
            T = table(Number,ID,Name_ja,Latitude,Longitude,MSL_RefLevel,MSL_TP,RefLevel_TP);
            return
        end
        
        %% Output time-series data 
        function outputTimeSeries(fname, stationlist, t, foutmatrix)
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

        %% Find the nearest station
        function stationname = findNearestStationForAstro(lonq,latq)
            if numel(lonq)~=numel(latq); error('Sizes of lon and lat must be the same.'); end
            if ~isnumeric(lonq)||~isnumeric(latq); error('Input arguments must be numeric.'); end
            nq = numel(lonq);
            stationname = cell(nq,1);
            T = JMAtide.createReferenceTableForAstro;
            [ind,dist] = dsearchn([T.Longitude, T.Latitude],[lonq(:), latq(:)]);
            for i = 1:nq
                if dist>2.0; fprintf('Not found: lon=%0.3f and lat=%0.3f (index=%d)\n',lonq(i),latq(i),i); end
                stationname{i} = T.Name_ja{ind(i)};
            end
            if nq==1; stationname = stationname{1}; end
            return
        end
    end
end