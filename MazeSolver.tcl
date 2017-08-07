# This template was designed and tested with tcl8.5
# we may include more packages if desired
package require Itcl
package require Itk
package require Tclx

# The user should pass in a text file to read as the maze input
if {$argc != 1} {
    puts "Incorrect number of inputs. Please run as:"
    puts "wish8.5 MazeSolver.tcl <fileName>"
    exit
}

# Global variables are defined here. The developer may define more, or choose a different approach.
#
# Contains the canvas object
variable _canvas
variable _xScroll
variable _yScroll
# Number of pixels to draw for each grid point
variable _unitWidth 15
variable _unitHeight 15
# Used in case the input maze file is too large to display all at once
variable _maxWindowWidth 500
variable _maxWindowHeight 500
# Initialiaze an empty list of list to store maze data
variable _mazeData

# This function should take in a filename to read as the input for the maze.
proc ReadFile {inputFileName} {
    if {![file isfile $inputFileName]} {
        puts "$inputFileName not found"
        return file_not_found
    }
    set fptr [open $inputFileName r]
    set lines [split [read $fptr] \n]

    variable _numRows
    variable _numCols

    set _numRows 0
    set _numCols 0
    lassign [split [lindex $lines 0] ,] _numRows _numCols
    if {![string is integer -strict $_numRows] || $_numRows < 1 \
                || ![string is integer -strict $_numRows] || $_numRows < 1} {
        puts "$inputFileName is not a valid maze file"
        return invalid_file
    }
    CreateCanvas $_numRows $_numCols
    # Current design reads the entire file, rather than relying on numRows or numCols.
    # If numRows/Cols does not match the file size, this could fail.
    set y 0
    # save the data to a list
    variable _mazeData
    set lIndex 0
    set _mazeData {};
    foreach line $lines {
        if { $lIndex != 0 } {
            lappend _mazeData [split $line {}]
        }
        incr lIndex
    }

    foreach line [lrange $lines 1 end] {
        # save the data to a list
        #lappend _mazeData [ list "$line"]
        for {set x 0} {$x < [string length $line]} {incr x} {
            if {[string index $line $x] == " "} {
                # This character is a empty space. Draw a white box.
                DrawSquare {*}[GridToPixel $x $y] hallway
            } else {
                # This character is a wall square.
                # The canvas background is already black, so don't need to draw anything
            }
        }
        incr y
    }

    set _mazeData $_mazeData
    set _numRows $_numRows
    set _numCols $_numCols
    return success
}

# This function is used to create and draw the canvas to show the user the screen
# Scrollbars are added for maze inputs too large to fit on the screen
# The developer can modify this function if desired
proc CreateCanvas {_numRows _numCols} {
    variable _canvas
    variable _xScroll
    variable _yScroll
    variable _unitWidth
    variable _unitHeight
    variable _maxWindowWidth
    variable _maxWindowHeight
    # Need to split this because the scrollbar doesn't seem to take without giving it the full size
    set fullWidth [expr {$_unitWidth * $_numRows + 1}]
    set fullHeight [expr {$_unitHeight * $_numCols + 1}]
    if {$fullWidth > $_maxWindowWidth} {
        set width $_maxWindowWidth
    } else {
        set width $fullWidth
    }
    if {$fullHeight > $_maxWindowHeight} {
        set height $_maxWindowHeight
    } else {
        set height $fullHeight
    }

    set _canvas [canvas .c]
    # Scrollbar code from http://wiki.tcl.tk/9268
    set _xScroll [scrollbar .sbx -orient horizontal -command "$_canvas xview"]
    set _yScroll [scrollbar .sby -orient vertical -command "$_canvas yview"]
    $_canvas configure -bg black \
            -width $width \
            -height $height \
            -xscrollcommand "$_xScroll set" \
            -yscrollcommand "$_yScroll set"

    pack $_xScroll -side bottom -fill x
    pack $_yScroll -side right -fill y
    pack $_canvas -side right -fill both -expand 1

    bind $_canvas <1> {FindShortestPathFromPixel %x %y}
    # canvas seems to need content drawn accross the full dimensions before the scrollbar is
    # effective. Therefore draw a border around the maze. This also solves the issue of if a user
    # manually resizes the window since the canvas is all black by default (same color as walls).
    $_canvas create line 0 0 0 $fullHeight -fill blue
    $_canvas create line $fullWidth 0 $fullWidth $fullHeight -fill blue
    $_canvas create line 0 $fullHeight $fullWidth $fullHeight -fill blue
    $_canvas create line 0 0 $fullWidth 0 -fill blue
    $_canvas configure -scrollregion [$_canvas bbox all]
    wm geometry . "${width}x${height}+100+100"
    return {}
}

# Clears existing content from the previous click.
# After calling it, the canvas should look as it did before the click.
proc Clear {} {
    variable _canvas
    # find withtag is not the most efficient possible solution here, because it is O(n^2)
    foreach rect [$_canvas find withtag bestPath] {
        $_canvas delete $rect
    }
    return {}
}

# For a given x y input (in pixels), and a tag indicating type, draw a square on the canvas color
# coded by type. The background of the canvas is already drawn black.
proc DrawSquare {x y tag} {
    variable _canvas
    variable _unitWidth
    variable _unitHeight

    if {$tag == {hallway}} {
        set fill white
    } elseif {$tag == {bestPath}} {
        set fill green
    } elseif {$tag == {turnAround}} {
        set fill red
    } else {
        # What else is there? The walls are already black from the canvas
        return "Unknown tag $tag"
    }
    $_canvas create rect $x $y [expr {$x + $_unitWidth}] [expr {$y + $_unitHeight}] \
            -fill $fill -tags $tag
    return {}
}

# Assumes x and y are integer pixel locations on the visible canvas.
# To account for the scrollbar modifying what portion of the canvas is visible, use canvasx/y.
# Returns a list containing the grid position of this pixel point (integers)
proc ClickedPixelToGrid {x y} {
    variable _canvas
    variable _unitWidth
    variable _unitHeight
    set canvasX [$_canvas canvasx $x]
    set canvasY [$_canvas canvasy $y]
    return [list [expr {int(($canvasX - 1) / $_unitWidth)}] \
                [expr {int(($canvasY - 1) / $_unitHeight)}]]
}

# Assumes x and y are integer grid points.
# Returns a list containing the upper left canvas pixel position of this grid point (integers)
proc GridToPixel {x y} {
    variable _unitWidth
    variable _unitHeight
    return [list [expr {$x * $_unitWidth + 1}] [expr {$y * $_unitHeight + 1}]]
}

# Recursive path finder
proc populatePath {valX valY {pathTaken {}}} {
    variable _numRows
    variable _numCols
    variable _mazeData

    # Make sure the variable is in context
    if {[info exists ::openRoute]} {
        return
    }
    # if already visited, go back
    if {0 <= [lsearch -exact $::visitedRoute $valX,$valY]} {
        DrawSquare {*}[GridToPixel $gridX $gridY] turnAround
        return
    }
    # get the current index value
    set value [lindex [lindex $_mazeData $valY] $valX]
    # if the value at current index is open and its in edge, it means we are out
    if {$valX == 0 || $valX == [expr {$_numRows - 1}] || $valY == 0 || $valY == [expr {$_numCols - 1}]} {
        if { $value == " " } {
            lappend pathTaken $valX,$valY
            set ::openRoute $pathTaken
            return
        }
    }
    # if it is a wall return
    if {$value == "#"} {
        return
    }
    # Add the current index to visited and current path data structures
    lappend ::visitedRoute $valX,$valY
    lappend pathTaken $valX,$valY
    # Iterate through all the elements in the maze
    # Go Left. Go West. X-1, Y
    # Go Right. Go East. X+1, Y
    # Go North. Go Up. X, Y-1
    # Go South. Go Down. X, Y+1
    foreach {xIncr yIncr} {-1 0 1 0 0 -1 0 1} {
        populatePath [expr {$valX+$xIncr}] [expr {$valY+$yIncr}] $pathTaken
    }
}

# This function is bound to the left mouse click. The input parameters are the location of
# the click. The remaining methodology is at the descretion of the developer.
proc FindShortestPathFromPixel {x y} {
    variable _mazeData
    variable _numRows
    variable _numCols

    puts "click occured at pixel $x $y, grid point [ClickedPixelToGrid $x $y]"
    # set the grid selected values
    set valX [lindex [ClickedPixelToGrid $x $y] 1]
    set valY [lindex [ClickedPixelToGrid $x $y] 0]
    # dump maze data stored to a file for verification if required
    set fileName "MazeDataDump.txt"
    set fileHndlr [open $fileName "w"]
    set rIndex 0
    foreach row $_mazeData {
        set cIndex 0
        foreach column $row {
            puts $fileHndlr "item at row $rIndex column $cIndex is $column"
            incr cIndex
        }
        incr rIndex
    }
    close $fileHndlr
    set ::visitedRoute {}
    #call the recursive path finder method
    populatePath $valX $valY
    # Draw the path
    set openRoutefileName "OpenRouteDataDump.txt"
    set openRoutefileHndlr [open $openRoutefileName [list WRONLY CREAT TRUNC]]
    set openRouteIndex 0
    foreach val $::openRoute {
        lassign [split $val ,] gridX gridY
        puts $openRoutefileHndlr "Route is open at $gridX & $gridY"
        DrawSquare {*}[GridToPixel $gridX $gridY] bestPath
        incr openRouteIndex
    }
    close $openRoutefileHndlr
}

# Now that the functions are sourced, read the input file
if {[ReadFile [lindex $argv 0]] != {success}} {
    exit
}

