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
scroll=0
shift=1
shift_size=50

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
height=250

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
</window>

<window>
height=100
fixed_height=0
<indicator>
name=Custom Indicator
<expert>
name=Average Range
flags=339
window_num=1
<inputs>
MA.Periods=20
MA.Method=SMA | LWMA* | EMA | SMMA
TrueRange=1
</inputs>
</expert>
color_0=16711680
weight_0=2
show_data=1
</indicator>
</window>
</chart>
