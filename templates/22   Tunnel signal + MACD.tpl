<chart>
symbol=GBPUSD
period=60
digits=5

leftpos=9229
scale=4
graph=0
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
askline_color=9639167
stops_color=17919

<window>
height=400
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
NumberOfInsideBars=2
</inputs>
</expert>
period_flags=31
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=MA Tunnel
flags=339
window_num=0
<inputs>
Tunnel.Definition=LWMA(55)
ShowChartLegend=1
AutoConfiguration=0
</inputs>
</expert>
weight_0=2
weight_1=2
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
MA.ReversalFilter=0.1
Draw.Type=Line | Dot*
Draw.Width=5
Color.UpTrend=16711680
Color.DownTrend=16776960
ShowChartLegend=1
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
MA.Periods=10
MA.ReversalFilter=0
Draw.Type=Line* | Dot
Draw.Width=3
Color.UpTrend=4678655
Color.DownTrend=4678655
ShowChartLegend=0
AutoConfiguration=0
</inputs>
</expert>
show_data=1
</indicator>
</window>

<window>
height=12
fixed_height=0

<indicator>
name=Custom Indicator
<expert>
name=MACD
flags=339
window_num=2
<inputs>
FastMA.Periods=12
FastMA.Method=SMA | LWMA | EMA* | ALMA
SlowMA.Periods=26
SlowMA.Method=SMA | LWMA | EMA* | ALMA
Histogram.Color.Upper=3329434
Histogram.Color.Lower=5275647
Histogram.Style.Width=2
MainLine.Width=0
Signal.onCross=1
Signal.onCross.Types=sound, alert
AutoConfiguration=0
</inputs>
</expert>
min=-0.001
max=0.001
show_data=1
</indicator>
</window>

<window>
height=12
fixed_height=0

<indicator>
name=Custom Indicator
<expert>
name=Tunnel signal
flags=339
window_num=2
<inputs>
Tunnel.MA.Method=SMA | LWMA* | EMA | SMMA | ALMA
Tunnel.MA.Periods=55
MA.Method=SMA | LWMA | EMA | SMMA | ALMA*
MA.Periods=10
Histogram.Color.Upper=3329330
Histogram.Color.Lower=255
Histogram.Style.Width= 2
Signal.onCross=1
Signal.onCross.Types=sound, alert
AutoConfiguration=0
</inputs>
</expert>
min=-1.0
max=1.0
show_data=1
</indicator>
</chart>
