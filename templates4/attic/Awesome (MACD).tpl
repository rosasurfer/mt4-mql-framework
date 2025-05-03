<chart>
symbol=USDCHF
period=60
digits=5

leftpos=13564
scale=4
graph=1
fore=0
grid=0
volume=0
scroll=0
shift=1
ohlc=0
askline=0
days=0
descriptions=1
shift_size=50
fixed_pos=620

window_left=0
window_top=0
window_right=1304
window_bottom=780
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
height=110

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
name=Moving Average
flags=339
window_num=0
<inputs>
MA.Periods=5
MA.Method=SMA
</inputs>
</expert>
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=Moving Average
flags=339
window_num=0
<inputs>
MA.Periods=34
MA.Method=SMA
UpTrend.Color=16711680
DownTrend.Color=16711680
</inputs>
</expert>
show_data=1
</indicator>
</window>

<window>
height=27
<indicator>
name=Awesome Oscillator
color=32768
style=0
weight=2
color2=255
style2=0
weight2=2
show_data=1
</indicator>

</window>
</chart>
