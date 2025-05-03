<chart>
symbol=GBPUSD
period=30
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
shift_0=0
draw_0=0
color_0=0
style_0=0
weight_0=0
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
ZigZag.Periods=30
ZigZag.Type=Line* | Semaphores
ZigZag.Width=0
ZigZag.Color=16711680
Donchian.ShowChannel=1
Donchian.Channel.UpperColor=16711680
Donchian.Channel.LowerColor=16711935
Donchian.Crossing.Symbol=dot* | narrow-ring | ring | bold-ring
</inputs>
</expert>
style_2=2
style_3=2
weight_4=0
weight_5=0
color_6=4294967295
color_7=4294967295
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=NonLagMA
flags=339
window_num=0
<inputs>
WaveCycle.Periods=25
Draw.Width=3
Color.UpTrend=16711935
Color.DownTrend=65535
</inputs>
</expert>
weight_0=0
weight_1=0
show_data=1
</indicator>

</window>
</chart>
