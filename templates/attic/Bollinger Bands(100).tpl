<!-- BollingerBands.tpl -->

<chart>
symbol=GBPUSD
period=60
digits=5

leftpos=9229
scale=1
graph=1
fore=0
grid=0
volume=0
ohlc=0
askline=0
days=0
descriptions=1
scroll=1
shift=1
shift_size=10

fixed_pos=620
window_left=0
window_top=0
window_right=1292
window_bottom=812
window_type=3

background_color=16316664
foreground_color=0
barup_color=30720
bardown_color=210
bullcandle_color=30720
bearcandle_color=210
chartline_color=11119017
volumes_color=30720
grid_color=14474460
askline_color=11823615
stops_color=17919

<window>
height=300

<indicator>
name=main
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Grid
flags=347
window_num=0
</expert>
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=ChartInfos
flags=347
window_num=0
</expert>
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=SuperBars
flags=339
window_num=0
<inputs>
</inputs>
</expert>
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Inside Bars
flags=339
window_num=0
<inputs>
Timeframe=H1
NumberOfInsideBars=3
</inputs>
</expert>
period_flags=3
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Bollinger Bands
flags=339
window_num=0
<inputs>
MA.Periods=100
MA.Method=SMA* | LWMA | EMA | SMMA | ALMA
MA.AppliedPrice=Open | High | Low | Close* | Median | Typical | Weighted
Bands.StdDevs=2
AutoConfiguration=0
</inputs>
</expert>
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Moving Average
flags=339
<inputs>
MA.Method=SMA | LWMA | EMA* | SMMA | ALMA
MA.Periods=144
MA.Periods.Step=56
Draw.Type=Line* | Dot
Draw.Width=3
UpTrend.Color=65535
DownTrend.Color=65535
ShowChartLegend=0
AutoConfiguration=0
</inputs>
</expert>
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Brackets
flags=339
window_num=0
<inputs>
TimeWindow=08:00-09:00
NumberOfBrackets=20
BracketsColor=9639167   ; DeepPink
AutoConfiguration=0
</inputs>
</expert>
period_flags=7
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Brackets
flags=339
window_num=0
<inputs>
TimeWindow=09:00-10:00
NumberOfBrackets=20
BracketsColor=16711680  ; Blue
AutoConfiguration=0
</inputs>
</expert>
period_flags=7
show_data=0
</indicator>

</window>
</chart>
