module d.ast.base;

public import sdc.location;

class Node {
	Location location;
	
	this(Location location) {
		this.location = location;
	}
}
