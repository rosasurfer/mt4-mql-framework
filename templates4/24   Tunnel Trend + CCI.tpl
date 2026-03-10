<!--
EMA(144)
ALMA(38)
LWMA(55) Channel + Channel Bars + Signal
CCI(14) + Signal
-->

<chart>
symbol=GBPUSD
period=60
digits=5

leftpos=9229
scale=4
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
height=4640
fixed_height=0

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
name=Moving Average
flags=339
window_num=0
<inputs>
MA.Method=SMA | LWMA | EMA* | SMMA | ALMA
MA.Periods=144
MA.Periods.Step=0
Draw.Type=Line* | Dot
Draw.Width=3
UpTrend.Color=65535
DownTrend.Color=65535
Background.Color=11119017
ShowChartLegend=0
AutoConfiguration=0
</inputs>
</expert>
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Trend Bars
flags=339
window_num=0
<inputs>
Channel.Method=SMA | LWMA* | EMA | SMMA | ALMA
Channel.Periods=55
Color.UpTrend=16711680
Color.DownTrend=255
Color.NoTrend=11119017
BarWidth=2
AutoConfiguration=0
</inputs>
</expert>
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=MA Channel
flags=339
window_num=0
<inputs>
Channel.Definition=LWMA(55)
ShowChartLegend=0
AutoConfiguration=0
</inputs>
</expert>
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=ALMA
flags=339
window_num=0
<inputs>
MA.Periods=38
MA.ReversalFilter.StdDev=0.2
UpTrend.Color=16711680
DownTrend.Color=16776960
Background.Color=16748574
ShowChartLegend=0
AutoConfiguration=0
</inputs>
</expert>
show_data=1
</indicator>
</window>

<window>
height=140
fixed_height=0
<indicator>
name=Custom Indicator
<expert>
name=Tunnel signal
flags=339
window_num=1
<inputs>
Tunnel.MA.Method=SMA | LWMA* | EMA | SMMA | ALMA
Tunnel.MA.Periods=55
MA.Method=SMA | LWMA | EMA | SMMA | ALMA*
MA.Periods=10
Signal.onTrendChange=1
Signal.onTrendChange.Types=sound* | alert* | mail
</inputs>
</expert>
min=-1.0
max=1.0
show_data=1
</indicator>
</window>

<window>
height=500
fixed_height=0
<indicator>
name=Custom Indicator
<expert>
name=CCI
flags=339
window_num=2
<inputs>
Periods=14
AppliedPrice=Open | High | Low | Close | Median | Typical* | Weighted
Signal.onTrendChange=1
Signal.onTrendChange.Types=sound* | alert* | mail
</inputs>
</expert>
draw_2=2
color_2=3329330
weight_2=2
draw_3=2
color_3=255
weight_3=2
min=-180
max=180
levels_color=12632256
levels_style=2
levels_weight=1
level_0=100
level_1=0
level_2=-100
show_data=1
</indicator>
</window>
</chart>
