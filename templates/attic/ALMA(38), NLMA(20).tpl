<chart>
symbol=USDCHF
period=30
digits=5

leftpos=13564
scale=2
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
window_bottom=1032
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
height=100

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
name=ALMA
flags=339
window_num=0
<inputs>
MA.Periods=38
UpTrend.Color=3329330
DownTrend.Color=255
Draw.Type=Line | Dot*
Draw.Width=3
</inputs>
</expert>
show_data=1
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=NonLagMA
flags=339
window_num=0
<inputs>
WaveCycle.Periods=20
MA.ReversalFilter.StdDev=0
Color.UpTrend=14772545
Color.DownTrend=65535
</inputs>
</expert>
show_data=1
</indicator>

</window>
</chart>
