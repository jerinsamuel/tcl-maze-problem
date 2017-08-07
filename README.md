# tcl-maze-problem

Given a maze, find your way out using Tcl

This solution is based on the wall following or wall hugging algorithm. 

CreateCanvas(all graphic procs) does not belong to me.

Steps:

1.	store the maze map to a data structure.
2.	Create data structures to store visited maze locations and the final open route chosen.
3.	Pick a starting point X, Y
4.	Invoke a recursive function using X, Y and path being followed.
a.	Check if this location is already visited. If so, return
b.	Check if this is a wall. If so, return.
c.	Check if this is an edge of the map and an open position. You found an exit. Store the path followed data structure to the final data store. Exit.
5.	Draw the map using the final data structure.

Rationale:

Solution was simple enough to be implemented in ~25LOCS.

Known Issues & Optimizations required:

1.	Major issues: To use larger mazes, Need to optimize the code.
2.	Major Issue: Few extra locations, which were open and visited gets added to the final map. Needs to trim the final map. 
3.	Minor Issue: An error message regarding data structure scope is shown intermittently. Not able to reproduce consistently.
4.	Minor issue: Redoing the solution again. Now it application needs to be closed. Need to use the clear function already in the program properly.

Steps to execute:

tclsh MazeSolver.tcl maze.txt

Or

tclsh MazeSolver.tcl maze2.txt
