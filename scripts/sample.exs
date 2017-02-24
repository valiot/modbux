alias Modbus.Master

#opto22 rack configured as follows
# m0 - 4p digital input
#  p0 - 24V
#  p1 - 0V
#  p2 - m1.p2
#  p3 - m1.p3
# m1 - 4p digital output
#  p0 - NC
#  p1 - NC
#  p2 - m0.p2
#  p3 - m0.p3

{:ok, pid} = Master.start_link([ip: {10,77,0,2}, port: 502])

#read 1 from input at slave 1 address 0 (m0.p0)
{:ok, [1]} = Master.tcp(pid, {:ri, 1, 0, 1})
#read 0 from input at slave 1 address 1 (m0.p1)
{:ok, [0]} = Master.tcp(pid, {:ri, 1, 1, 1})
#read both previous inputs at once
{:ok, [1, 0]} = Master.tcp(pid, {:ri, 1, 0, 2})

#turn off coil at slave 1 address 6 (m1.p2)
:ok = Master.tcp(pid, {:fc, 1, 6, 0})
:timer.sleep(50) #let output settle
#read 0 from input at slave 1 address 2 (m0.p2)
{:ok, [0]} = Master.tcp(pid, {:ri, 1, 2, 1})

#turn on coil at slave 1 address 7 (m1.p3)
:ok = Master.tcp(pid, {:fc, 1, 7, 1})
:timer.sleep(50) #let output settle
#read 1 from input at slave 1 address 3 (m0.p3)
{:ok, [1]} = Master.tcp(pid, {:ri, 1, 3, 1})
