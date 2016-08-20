
alias Modbus.Master
{:ok, pid} = Master.start_link([ip: {10,77,0,215}, port: 502])

delay = 10
points = [0,1,2,3]

for i <- 0..100000 do

  :io.format "~p ~n", [i]

  for n <- Enum.shuffle points do
    :ok = Master.tcp(pid, {:fc, 1, 4 + n, 1}, 400)
    :timer.sleep(delay)
    {:ok, [1]} = Master.tcp(pid, {:rc, 1, 4 + n, 1}, 400)
    :timer.sleep(2*delay)
    {:ok, [1]} = Master.tcp(pid, {:rc, 1, 0 + n, 1}, 400)
  end
  :timer.sleep(2*delay)
  {:ok, [1,1,1,1]} = Master.tcp(pid, {:rc, 1, 0, 4}, 400)

  for n <- Enum.shuffle points do
    :ok = Master.tcp(pid, {:fc, 1, 4 + n, 0}, 400)
    :timer.sleep(delay)
    {:ok, [0]} = Master.tcp(pid, {:rc, 1, 4 + n, 1}, 400)
    :timer.sleep(2*delay)
    {:ok, [0]} = Master.tcp(pid, {:rc, 1, 0 + n, 1}, 400)
  end
  :timer.sleep(2*delay)
  {:ok, [0,0,0,0]} = Master.tcp(pid, {:rc, 1, 0, 4}, 400)

end
