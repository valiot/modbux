#run with: mix slave
alias Modbus.Tcp.Slave
alias Modbus.Tcp.Master

#start your slave with a shared model
model = %{ 0x50=>%{ {:c, 0x5152}=>0 } }
{:ok, spid} = Slave.start_link([model: model])
#get the assigned tcp port
{:ok, %{port: port}} = Slave.id(spid)

#interact with it
{:ok, mpid} = Master.start_link([ip: {127,0,0,1}, port: port])
{:ok, [0]} = Master.exec(mpid, {:rc, 0x50, 0x5152, 1})
