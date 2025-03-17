<chart>
symbol=USDCHF
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
chartline_color=8421504
volumes_color=30720
grid_color=14474460
askline_color=11823615
stops_color=17919

<window>
height=281

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
name=Moving Average
flags=339
window_num=0
<inputs>
MA.Method=SMA | LWMA | EMA* | SMMA | ALMA
MA.Periods=144
MA.Periods.Step=56
Draw.Width=2
UpTrend.Color=16711935
DownTrend.Color=16711935
Background.Color=-1
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
UpTrend.Color=16760576
DownTrend.Color=65535
</inputs>
</expert>
show_data=1
</indicator>
</window>

<window>
height=50
fixed_height=0
<indicator>
name=Custom Indicator
<expert>
name=MACD
flags=339
window_num=1
<inputs>
FastMA.Periods=8
FastMA.Method=SMA | LWMA | EMA | SMMA| ALMA*
SlowMA.Periods=38
SlowMA.Method=SMA | LWMA | EMA | SMMA| ALMA*
</inputs>
</expert>
show_data=1
</indicator>
</window>

<window>
height=50
fixed_height=0
<indicator>
name=Custom Indicator
<expert>
name=BFX Delta
flags=339
window_num=1
<inputs>
</inputs>
</expert>
show_data=1
</indicator>

</window>
</chart>
