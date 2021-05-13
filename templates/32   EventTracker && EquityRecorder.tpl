<chart>
symbol=GBPUSD
period=60
leftpos=9229
digits=5
scale=1
graph=1
fore=0
grid=0
volume=0
scroll=1
shift=1
ohlc=0
askline=0
days=0
descriptions=1
shift_size=12
fixed_pos=620
window_left=0
window_top=0
window_right=1292
window_bottom=812
window_type=3
background_color=16316664
foreground_color=0
barup_color=-1
bardown_color=-1
bullcandle_color=-1
bearcandle_color=-1
chartline_color=-1
volumes_color=-1
grid_color=-1
askline_color=-1
stops_color=17919

<window>
height=300

<indicator>
name=main
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=ChartInfos
flags=347
window_num=0
<inputs>
Track.Orders=off
</inputs>
</expert>
period_flags=0
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=EventTracker
flags=339
window_num=0
<inputs>
Track.Orders=on
Track.Signals=on
</inputs>
</expert>
period_flags=0
show_data=0
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=EquityRecorder
flags=339
window_num=0
</expert>
period_flags=0
show_data=0
</indicator>

</window>
</chart>
