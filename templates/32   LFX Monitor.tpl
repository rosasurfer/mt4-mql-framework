<chart>
symbol=GBPAUD
period=60
digits=5

leftpos=17392
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
shift_size=50

fixed_pos=620
window_left=0
window_top=47
window_right=996
window_bottom=632
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
height=10

<indicator>
name=main
</indicator>

<indicator>
name=Custom Indicator
<expert>
name=LFX-Monitor
flags=339
window_num=0
<inputs>
AUDLFX.Enabled=1
CADLFX.Enabled=1
CHFLFX.Enabled=1
EURLFX.Enabled=1
GBPLFX.Enabled=1
JPYLFX.Enabled=1
NZDLFX.Enabled=1
USDLFX.Enabled=1
NOKFX7.Enabled=1
SEKFX7.Enabled=1
SGDFX7.Enabled=1
ZARFX7.Enabled=1
USDX.Enabled=1
EURX.Enabled=1
XAUI.Enabled=1
Recording.Enabled=1
Recording.HistoryDirectory=history/XTrade-Synthetic
Recording.HistoryFormat=400
</inputs>
</expert>
color_0=4294967295
show_data=0
</indicator>

</window>
</chart>
