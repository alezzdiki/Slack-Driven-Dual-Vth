# Slack-Driven-Dual-Vth #
### Postsynthesis optimization through cells swapping ###


Firstly, let’s check the feasibility after the script is started with parameters:
* The arrival time required by the user must be greater than the arrival time of the Critical Path
* The number of Quasi Critical Paths present into the slack window must be lower than the number of Paths inserted by the user.
If both conditions are satisfied, the script is feasible and computation can start.
Another important step is to define a functions cost:

                                        Δleak = LVTleak – HVTleak

Now, we can use a significant criteria to assign a priority for those cell that should be swapped from LVT to HVT. 
After many simulations, the average value for both benchmarks (c1908 and c5315) doesn’t change significantly, so:
                              
                              Δleak_1908_avg = 1.4   and   Δleak_5315_avg = 2.4
                              
Let’s choose a K value such that is equal to `min(Δleak_1908_avg  , Δleak_5315_avg)`. Otherwise, more than the 50% of cells c1908 benchmark might be excluded. This value is called *factor_exit*. After that the *factor_exit* value has been calculated offline, it’s used as a constant value in the script in the following way:
At the beginning, *factor_exit* is the minimum difference of the leakage so that a cell can be considered as a possible candidate for swapping, then the idea is to calculate a factor k of all cells, such that if `k > factor_exit` then the cell can be considered as possible candidate for swapping otherwise not. This approach is very slow because each cell should be charged `k = Δleak`, then we would have to swap 2 times more the cells **(LVH -> HVT -> LVT)**.

Then, starting from the previous idea, k is computed for each cell as `k = LVTleak - factor_exit` and if `k > 0`, then the cell can be considered as candidates for swapping otherwise not.
The key point is the same and will get the same result in terms of power-savings, however the execution time improves. Therefore: 
if `k > 0`  , its value is stored with the cell’s full name into a specific list (*list_par_cell*), which will be sorted for increasing values of *k*. In this way, only cells that might give a significant gain are put into the list.
The slack window is computed as:

**Left boundary** = *Clock period - clock uncertainty – output external delay – arrival time*

**Right boundary** = *Clock period – clock uncertainty – output external delay – arrival time + slack win*

When the *k* value of all cells are computed, cells are swapped and the script check if starting conditions are violated. To check this, is necessary to compute, again, the feasibility conditions as above. 
This procedure is repeated for each element of the *list_par_cell*, then, the execution of the script is completed.
