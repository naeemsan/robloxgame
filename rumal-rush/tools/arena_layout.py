"""One deterministic arena definition shared by the place and Rojo model export."""
import math

TEAL = (62, 201, 185)
CORAL = (247, 109, 94)
INK = (23, 35, 49)
CREAM = (255, 243, 214)
GOLD = (255, 207, 87)

def arena():
    parts, signs = [], []
    def part(name, size, pos, color, **kwargs):
        parts.append(dict(name=name, size=size, pos=pos, color=color, **kwargs))
    def sign(name, text, pos, size=(24, 8, 1), color=INK, text_color=CREAM, face='Front'):
        part(name, size, pos, color)
        signs.append(dict(part=name, text=text, color=text_color, face=face))
    part('Island', (152, 6, 132), (0, -3.2, 4), (208, 170, 126))
    part('Courtyard', (99, .4, 67), (0, -.2, 0), (244, 221, 183))
    part('Court', (88, .12, 58), (0, .06, 0), (231, 190, 140))
    part('TealHome', (10, .14, 58), (-39, .08, 0), TEAL)
    part('CoralHome', (10, .14, 58), (39, .08, 0), CORAL)
    for x in (-34, 34):
        part('HomeLine', (.3, .18, 58), (x, .12, 0), CREAM, collide=False)
    for z in (-29, 29):
        part('Sideline', (88, .18, .3), (0, .12, z), CREAM, collide=False)
    part('CenterLine', (.18, .16, 58), (0, .1, 0), (247, 230, 199), collide=False)
    part('CenterDisc', (.12, 11, 11), (0, .18, 0), CREAM, shape='Cylinder', rotation=(0,0,90), collide=False)
    part('CenterInner', (.14, 8, 8), (0, .26, 0), GOLD, shape='Cylinder', rotation=(0,0,90), collide=False)
    # No obstacles in the playable court: tags use clear distance checks.
    for x in (-46, 46):
        part('Boundary', (2, 3, 65), (x, 1.5, 0), (201, 141, 111))
        part('BoundaryCap', (2.4, .5, 65), (x, 3.25, 0), CREAM)
    for z in (-32, 32):
        part('Boundary', (92, 3, 2), (0, 1.5, z), (201, 141, 111))
        part('BoundaryCap', (92, .5, 2.4), (0, 3.25, z), CREAM)
    # A separated viewing deck keeps non-active players away from the court.
    part('SpectatorDeck', (90, 4, 19), (0, 1, 44), (51, 67, 76))
    for z,y in ((38,3.2),(43,4.2),(48,5.2)):
        part('Bench', (78, 1.2, 3), (0,y,z), (235, 185, 119))
    part('LobbySpawn', (8, .5, 6), (0, 6.3, 48), TEAL, spawn=True)
    sign('MainSign', 'RUMAL RUSH', (0, 14, -39), (44, 9, 1.5))
    sign('SubSign', 'GRAB. DODGE. GET HOME.', (0, 8.3, -39), (44, 2.8, 1), TEAL, INK)
    for x in (-21,21): part('SignPost', (1, 18, 1), (x, 8, -39), INK)
    sign('TealSign', 'TEAL\nHOME', (-39, 7, -34), (10, 5, 1), TEAL, INK)
    sign('CoralSign', 'CORAL\nHOME', (39, 7, -34), (10, 5, 1), CORAL, INK)
    # Compact stylized mohallah facades; simple geometry, no asset downloads.
    building_colors = [(231,148,118),(130,183,177),(245,205,126),(181,164,199)]
    for i,x in enumerate((-62,-43,43,62)):
        height = (17,23,21,16)[i]
        part('Townhouse', (16,height,13), (x,height/2,-49), building_colors[i])
        part('RoofTrim', (17,1,14), (x,height+.5,-49), CREAM)
        part('Door', (4,7,.3), (x,3.5,-42.3), INK)
        for wx in (-4,4):
            part('Window', (3,3,.3), (x+wx,12,-42.3), (42,77,91))
            part('WindowLintel', (3.8,.4,.7), (x+wx,10.3,-42), CREAM)
        part('Awning', (12,.5,4), (x,8,-40.5), TEAL if i%2 else CORAL)
    for x in (-60,60):
        for z in (-15,16,48):
            part('Planter', (7,2.5,7), (x,1.25,z), (187,117,91))
            part('TreeTrunk', (1.7,9,1.7), (x,6,z), (128,90,69))
            part('TreeCrown', (10,10,10), (x,12,z), (91,155,111), shape='Ball')
            part('TreeCrownSmall', (7,7,7), (x+3,14,z+1), (121,178,121), shape='Ball')
    # Bunting high above the back edge, never across the camera.
    part('BuntingString', (94,.12,.12), (0,24,-33), INK, collide=False)
    for i in range(19):
        part('Pennant', (2,2.8,.12), (-45+i*5,22.6,-33), (TEAL,CORAL,GOLD)[i%3], collide=False)
    for x in (-30,-20,20,30):
        part('SpectatorBody', (2.4,3,1.5), (x,8,48), (TEAL,CORAL)[int(abs(x)/10)%2], collide=False)
        part('SpectatorHead', (1.8,1.8,1.8), (x,10.4,48), (211,161,119), shape='Ball', collide=False)
    return parts, signs
