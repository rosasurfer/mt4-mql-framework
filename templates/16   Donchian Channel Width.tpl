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
askline_color=11823615
stops_color=17919

<window>
height=700
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
name=ZigZag
flags=339
window_num=0
<inputs>
ZigZag.Periods=45
ZigZag.Width=0
ZigZag.Color=9639167
Donchian.ShowChannel=1
Donchian.ShowCrossings=off | first* | all
Donchian.Crossings.Width=2
Donchian.Upper.Color=16711935
Donchian.Lower.Color=16711935
</inputs>
</expert>
style_2=2
style_3=2
color_6=4294967295
color_7=4294967295
show_data=1
</indicator>
</window>

<window>
height=200
fixed_height=0
<indicator>
name=Custom Indicator
<expert>
name=Donchian Channel Width
flags=339
window_num=1
<inputs>
Donchian.Periods=45
</inputs>
</expert>
color_0=16711680
weight_0=2
period_flags=0
show_data=1
</indicator>
</window>
</chart>
