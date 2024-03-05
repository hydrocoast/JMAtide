# 気象庁 潮汐観測資料 確定値 データ取得

## 概要
このリポジトリは[気象庁](https://www.jma.go.jp/jma/index.html)
がウェブサイトで公開している「潮位表」の推算潮位（天文潮位）および「潮汐観測資料」の毎時潮位・潮位偏差のデータ取得ツールです．
[潮位表 テキストファイルフォーマット](https://www.data.jma.go.jp/gmd/kaiyou/db/tide/suisan/readme.html)
および
[潮汐観測資料 テキストファイルフォーマット](https://www.data.jma.go.jp/gmd/kaiyou/db/tide/genbo/format.html)
を参考にテキストファイルを読み取ることで実行されます．
実行には MATLAB が必要です．

## 潮位表（天文潮位の推算値）読み取り
### 基本
取得したい地点名・年・月を入力してインスタンスを生成します．
```matlab
station = JMAtide('能登', 2024, 1);
```
続いて，loadastronimocaltide メソッドでそれぞれ潮位，潮位偏差を気象庁ウェブサイトから取得します． 
格納されるプロパティ名は AstronomicalTide です．
```matlab
station = station.loadastronimocaltide; % 推算潮位の取得
```

plotastronomicaltide で取得したデータの簡易的なプロットが可能です．
```matlab
% 潮位のプロット
station.plotastronomicaltide;
```
<p align="center">
<img src="/images/figure_atide_ex.png", width="450">
</p>


### 最も近い潮位表掲載地点の検出
緯度経度を入力して，一番近い潮位表の掲載地点を求めることもできます．
```matlab
stationname = JMAtide.findNearestStationForAstro([136.674; 137.263], [37.168; 37.434]) % lon, lat

stationname =
  2×1 の cell 配列
    {'輪島'}
    {'能登'}
```

### 特定時刻の推算（天文）潮位の取得
月ごとの推算潮位を取得後に datetime 型で日時を指定することで，特定時刻の推算潮位を毎時データから内挿で求めることができます．
```matlab
% 2024年1月
station = JMAtide(stationname, 2024, 1);
% 毎時推算潮位取得
station = station.loadastronimocaltide;
% 特定時刻の推算潮位の抽出 2024/01/25T19:15
atide = station.getastronomicaltide(datetime(2024,1,25,19,15,0,0))

atide =
   21.0000
   24.8500
```
対象期間外の時刻を指定して潮位を取得しようとした場合，NaN を返します．
```matlab
% 2024年1月でない時刻の指定
station.getastronomicaltide(datetime(2024,2,1,3,10,0,0))

ans =
   NaN
   NaN
```

## 観測潮位，潮位偏差の読み取り
### 基本
気象庁の毎時潮位観測資料は，地点ごとおよび月ごとにファイルが分かれています．
このため，観測地点名・年・月を入力してインスタンスを生成し，変数の初期化を行います．

```matlab
tidegauge = JMAtide('東京', 2019, 10);
```

loadssh, loadssha でそれぞれ潮位，潮位偏差を気象庁ウェブサイトから取得します．
格納されるプロパティ名は ssh と ssha です．

```matlab
tidegauge = tidegauge.loadssh; % 潮位
tidegauge = tidegauge.loadssha; % 潮位偏差
```

plotssh，plotssha で取得したデータの簡易的なプロットが可能です．

```matlab
% 潮位のプロット
tidegauge.plotssh;
```
<p align="center">
<img src="/images/figure_0.png", width="600">
</p>

```matlab
% 潮位偏差のプロット
tidegauge.plotssha;
```
<p align="center">
<img src="/images/figure_1.png", width="600">
</p>

### 長期（２ヶ月以上）のデータ取得
年月の指定部分に配列を入力することで，長期間の潮位データを対象とすることが可能です．

```matlab
tidegauge = JMAtide('東京', 2019);               % 2019年1月〜12月, (1x12)配列
tidegauge = JMAtide('東京', [2018,09; 2019,10]); % 2018年9月 と 2019年10月, (1x2)配列
tidegauge = JMAtide('東京', 2019, 8:11)          % 2019年9月〜11月, (1x4)配列
```

| |      1      |      2      |      3      |      4      |
| :-: | :---------: | :---------: | :---------: | :---------: |
| 1 | 1x1 JMAtide | 1x1 JMAtide | 1x1 JMAtide | 1x1 JMAtide |

```matlab
tidegauge = tidegauge.loadssha;
tidegauge.plotssha;
```
<p align="center">
<img src="/images/figure_2.png", width="600">
</p>

### 複数地点のデータ取得
地点名を cell 配列で複数指定すると，複数地点の潮位データを同時に扱えます．

```matlab
% 以下の9地点，2019年10月
tidegauge = JMAtide({'布良','東京','岡田','三宅島（坪田）','小田原','石廊崎','内浦','清水港','御前崎'}, 2019, 10);

% 潮位取得
tidegauge = tidegauge.loadssh;

% 潮位偏差取得
tidegauge = tidegauge.loadssha;

% plot - 潮位偏差
lines = tidegauge.plotssha;
xlim([tidegauge(1).Time(24*8)+hours(1), tidegauge(1).Time(24*14)])
legend(lines, {'布良','東京','岡田','三宅島（坪田）','小田原','石廊崎','内浦','清水港','御前崎'}, 'NumColumns',2, 'Location','NorthWest');
```
<p align="center">
<img src="/images/figure_3.png", width="600">
</p>

### CSVファイルへの出力
csvssh，csvsshaでそれぞれ潮位，潮位偏差を csv ファイルとして出力します．
データの期間（年，月）が同じであれば，複数の地点を1つのファイルにまとめて出力します．

```matlab
% ファイル出力前に，単位を cm → m へ
tidegauge = tidegauge.convertunit('m');

% CSVファイルとして出力
% 同一期間のため，全地点のデータを1つのファイルに格納
tidegauge.csvssh  % 潮位
tidegauge.csvssha % 潮位偏差

  sealevel_201910_MRTKOKMJODG9UCSMOM.dat  
  sealevelanomaly_201910_MRTKOKMJODG9UCSMOM.dat
```
```matlab
% 出力ファイルの確認 1行目〜10行目
dbtype sealevel_201910_MRTKOKMJODG9UCSMOM.dat 1:10
```
```text
1     # time, 布良, 東京, 岡田, 三宅島（坪田）, 小田原, 石廊崎, 内浦, 清水港, 御前崎
2     20191001T0000,    0.830,    1.080,    0.840,    3.770,    2.760,    3.250,    1.040,    1.320,    1.530
3     20191001T0100,    0.980,    1.130,    0.930,    3.840,    2.870,    3.220,    1.030,    1.260,    1.510
4     20191001T0200,    1.250,    1.390,    1.160,    4.080,    3.120,    3.370,    1.220,    1.370,    1.670
5     20191001T0300,    1.570,    1.790,    1.480,    4.400,    3.450,    3.660,    1.560,    1.610,    1.960
6     20191001T0400,    1.870,    2.230,    1.800,    4.710,    3.770,    4.030,    1.940,    1.950,    2.300
7     20191001T0500,    2.060,    2.600,    2.040,    4.970,    4.000,    4.400,    2.280,    2.300,    2.630
8     20191001T0600,    2.130,    2.820,    2.140,    5.120,    4.100,    4.650,    2.510,    2.570,    2.850
9     20191001T0700,    2.050,    2.810,    2.120,    5.140,    4.060,    4.740,    2.590,    2.700,    2.930
10    20191001T0800,    1.840,    2.610,    1.970,    5.000,    3.890,    4.640,    2.500,    2.640,    2.850
```

## 注意
- 速報値ではなく，確定値が格納されたファイルを取得します．
- [観測地点一覧表（気象庁）](https://www.data.jma.go.jp/gmd/kaiyou/db/tide/genbo/station.php)の地点記号，観測地点名をもとにしています．この表に記載されている通りに地点名を入力しないと値を取得できません
  （例：×三宅島，✔︎三宅島（坪田））．また，年月日によっては掲載されていても取得できない地点があります．

## License
MIT

## Author
[Takuya Miyashita](https://github.com/hydrocoast)
miyashita@hydrocoast.jp
