count = 250;
radius = 32;
seed = 0;

chaff_lenght = 1;
chaff_width = 0.5;
chaff_height = 0.001;

rs = rands(0, radius, count, seed);
thetas = rands(0, 180, count, seed+1);
phis = rands(0, 360, count, seed+2);
rots = rands(0, 360, count, seed+3);

for (i = [0 : count-1]) {
    x = rs[i] * sin(thetas[i]) * cos(phis[i]);
    y = rs[i] * sin(thetas[i]) * sin(phis[i]);
    z = rs[i] * cos(thetas[i]);
    
    translate([x, y, z]) {
        rotate([rots[i], rots[(i+37)%count], rots[(i+73)%count]]) {
            cube([chaff_width, chaff_height, chaff_lenght], center=true);
        }
    }
}
