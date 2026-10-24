"""The Last Ember: deterministic architectural layout and interaction markers."""
import random
rng=random.Random(731)
WOOD=(42,33,28);WALL=(68,66,59);TRIM=(31,29,27);IRON=(36,39,40)
def layout():
    rng=random.Random(731)
    parts,lights,signs,markers=[],[],[],[]
    def p(name,size,pos,color,material=256,rotation=(0,0,0),**extra):
        parts.append(dict(name=name,size=size,pos=pos,color=color,material=material,rotation=rotation,**extra))
    def label(name,words,pos,size=(10,2,.2)):
        p(name,size,pos,TRIM,512)
        signs.append(dict(part=name,text=words,color=(178,168,138)))
    def lamp(name,pos,brightness=1.3,color=(235,160,91),range_=22,shadow=True):
        p(name,(.45,.85,.45),pos,color,288,collide=False)
        lights.append(dict(part=name,color=color,brightness=brightness,range=range_,shadows=shadow))
        p(name+'Bracket',(.25,1.8,.35),(pos[0],pos[1]-.55,pos[2]+.25),IRON,1088)
    def wallX(name,x,z0,z1,door=None):
        spans=[(z0,z1)] if door is None else [(z0,door-5),(door+5,z1)]
        for a,b in spans:
            p(name,(1.2,18,b-a),(x,9,(a+b)/2),WALL,816)
            p('Skirting',(.2,1.1,b-a),(x+.7,.55,(a+b)/2),TRIM,512)
            p('Skirting',(.2,1.1,b-a),(x-.7,.55,(a+b)/2),TRIM,512)
            for z in range(int(a)+3,int(b)-1,7):
                p('WallPanel',(.13,5,5),(x+.65,3.5,z),(48,44,37),512,collide=False)
                p('WallPanel',(.13,5,5),(x-.65,3.5,z),(48,44,37),512,collide=False)
        if door is not None:
            p('Lintel',(1.8,5,10),(x,15.5,door),TRIM,512)
            for z in (door-5,door+5):p('DoorFrame',(1.8,13,.6),(x,6.5,z),TRIM,512)
    def wallZ(name,z,x0,x1,door=None):
        spans=[(x0,x1)] if door is None else [(x0,door-5),(door+5,x1)]
        for a,b in spans:
            p(name,(b-a,18,1.2),((a+b)/2,9,z),WALL,816)
            p('Skirting',(b-a,1.1,.2),((a+b)/2,.55,z+.7),TRIM,512)
            p('Skirting',(b-a,1.1,.2),((a+b)/2,.55,z-.7),TRIM,512)
        if door is not None:
            p('Lintel',(10,5,1.8),(door,15.5,z),TRIM,512)
            for x in (door-5,door+5):p('DoorFrame',(.6,13,1.8),(x,6.5,z),TRIM,512)
    p('Foundation',(144,4,158),(0,-2,10),(24,27,28),800)
    p('MainFloor',(122,.5,100),(0,-.25,0),WOOD,528)
    p('FurnaceFloor',(28,.5,18),(0,-.25,-58),(47,44,40),816)
    p('FrontGarden',(90,.4,38),(0,-.2,70),(31,35,32),800)
    p('Walkway',(16,.2,31),(0,.12,68),(75,73,66),880)
    p('HallRunner',(9,.08,94),(0,.07,0),(57,29,28),1312,collide=False)
    for x in (-4.2,4.2):p('RunnerBorder',(.15,.09,94),(x,.1,0),(117,94,57),1312,collide=False)
    wallX('OuterWall',-61,-50,50);wallX('OuterWall',61,-50,50)
    wallZ('BackWall',-50,-61,61,0);wallZ('FrontWall',50,-61,61,0)
    wallX('HallWall',-12,-50,50,-28);wallX('HallWall',12,-50,50,28)
    # Additional door openings in hall walls at the opposite rooms.
    # Replace the long walls above with split segments, giving each wing two real doorways.
    parts[:]=[s for s in parts if not (s['name'] in ('HallWall','Skirting','WallPanel','Lintel','DoorFrame') and
        abs(abs(s['pos'][0])-12)<1)]
    wallX('HallWall',-12,-50,-8,-28);wallX('HallWall',-12,8,50,28)
    wallX('HallWall',12,-50,-8,-28);wallX('HallWall',12,8,50,28)
    wallZ('RoomDivider',-8,-61,-12,-36);wallZ('RoomDivider',8,-61,-12,-36)
    wallZ('RoomDivider',-8,12,61,36);wallZ('RoomDivider',8,12,61,36)
    wallX('FurnaceWall',-14,-67,-50);wallX('FurnaceWall',14,-67,-50);wallZ('FurnaceBack',-67,-14,14)
    p('Ceiling',(124,.7,102),(0,18.35,0),(27,29,28),816)
    p('FurnaceCeiling',(29,.7,18),(0,18.35,-58.5),(22,24,23),816)
    for z in range(-45,50,12):
        p('CeilingBeam',(122,1.1,1.2),(0,17.3,z),TRIM,512)
    for x in (-12,12):
        p('Crown',(1.8,.7,100),(x,17,0),(88,82,68),512)
    # Shuttered windows: moonlight enters through narrow slats.
    for x in (-60.25,60.25):
        for z in (-33,30):
            p('WindowRecess',(.2,8,10),(x,10,z),(10,16,24),256,collide=False)
            for dz in (-4,-2,0,2,4):
                p('Shutter',(.4,7.4,1.4),(x-.2 if x>0 else x+.2,10,z+dz),(36,43,46),512)
            lamp('Moonlight'+str(x)+str(z),(x*.96,11,z),1.5,(102,137,172),30,False)
    for z in (-40,-15,15,40):lamp('HallLamp'+str(z),(9.8,10,z),1.1,(228,156,92),21)
    lamp('ChapelLamp',(-41,10,-45),.8,(198,145,89),27)
    lamp('WardLamp',(39,10,-43),.7,(155,183,166),28)
    lamp('KitchenLamp',(-45,9,44),.9,(221,161,95),26)
    lamp('ArchiveLamp',(48,9,43),.65,(226,167,113),28)
    lamp('FurnaceLight',(0,7,-62),2.2,(243,103,36),27)
    lamp('EntranceLantern',(-7,9,53),1.8,(239,172,91),30)
    lamp('EntranceLantern2',(7,9,53),1.8,(239,172,91),30)
    # Chapel: wooden pews, candles, a shrouded altar.
    for z in (-19,-29,-39):
        for x in (-23,-48):
            p('PewSeat',(13,.7,3),(x,2,z),WOOD,512)
            p('PewBack',(13,3,.6),(x,3.2,z-1.4),WOOD,512)
            for dx in (-5,5):p('PewLeg',(.6,2,2),(x+dx,1,z),TRIM,512)
    p('Altar',(10,4,5),(-36,2,-45),(62,61,55),784)
    p('AltarCloth',(10.4,.15,5.3),(-36,4.1,-45),(111,103,84),1312)
    for x in (-40,-37,-34,-31):
        p('Candle',(.35,1.5,.35),(x,4.9,-44),(181,169,129),256)
        p('CandleFlame',(.15,.4,.15),(x,5.85,-44),(242,187,91),288,collide=False)
    # Ward: iron beds and hanging curtains along the far wall.
    for x in (24,43):
        for z in (-23,-40):
            p('BedFrame',(10,1,6),(x,2,z),IRON,1088)
            p('Mattress',(9.5,1.2,5.6),(x,3,z),(112,112,98),1312)
            p('Pillow',(2.5,.5,4),(x-3.3,3.9,z),(145,140,119),1312)
            for dx in (-4.7,4.7):
                for dz in (-2.7,2.7):p('BedPost',(.25,5,.25),(x+dx,2.5,z+dz),IRON,1088)
            p('BedStain',(3,.025,2),(x+1,3.62,z),(77,79,70),1312,collide=False)
    # Kitchen furnishings, preserving the doorway-to-doorway route.
    p('KitchenCounter',(31,4,5),(-38,2,45),(54,49,42),512)
    p('CounterTop',(32,.4,5.5),(-38,4.2,45),(103,101,87),784)
    for x in (-49,-39,-29):
        p('CabinetDoor',(8,3.2,.3),(x,2.2,42.3),(63,56,44),512)
        p('CabinetHandle',(1,.15,.25),(x,2.5,42),IRON,1088)
    p('KitchenTable',(13,.6,8),(-41,3.5,25),WOOD,512)
    for x in (-46,-36):
        for z in (22,28):p('TableLeg',(.7,3.4,.7),(x,1.7,z),TRIM,512)
    for i in range(5):
        p('DirtyPlate',(.13,2,2),(-45+i*2,3.9,25),(132,127,108),256,(0,0,90),shape='Cylinder')
    p('Stove',(6,5,5),(-55,2.5,38),IRON,1040)
    # Archives: tall bookcases and a mission journal.
    for x in (18,54):
        p('BookcaseBack',(5,12,28),(x,6,29),WOOD,512)
        for y in (1,4,7,10,12):
            p('Shelf',(6,.35,28),(x,y,29),TRIM,512)
        for row in range(3):
            for j in range(9):
                h=rng.uniform(1.6,2.7)
                p('OldBook',(4,h,1.4),(x,row*3+1.7+h/2,17+j*2.6),
                    rng.choice([(64,45,39),(63,67,57),(73,63,44),(42,54,59)]),512)
    p('ArchiveDesk',(13,.6,7),(37,3.5,35),WOOD,512)
    for x in (32,42):
        for z in (32.5,37.5):p('DeskLeg',(.65,3.5,.65),(x,1.75,z),TRIM,512)
    for i in range(6):
        p('LoosePaper',(2,.025,2.7),(34+i*.9,3.83,34+i*.25),(160,150,118),256,(0,i*13,0),collide=False)
    # Furnace, generator and front door are named interaction anchors.
    p('Generator',(5,5,9),(-55,2.5,0),(42,52,48),1088)
    p('GeneratorPanel',(.3,3,3),(-52.3,3,0),(73,86,76),1088)
    for z in (-.8,.8):p('FuseSocket',(.12,.8,.5),(-52.1,3,z),(14,17,16),256,collide=False)
    p('Furnace',(12,10,7),(0,5,-63),(48,44,40),848)
    p('FurnaceMouth',(6,5,.3),(0,3.4,-59.3),(7,8,8),256)
    p('FurnaceGrate',(6,.3,3),(0,1,-58),(53,45,38),1040)
    for x in (-2.5,-1.5,-.5,.5,1.5,2.5):p('FurnaceBar',(.15,4,.2),(x,3.3,-59),(25,24,22),1088)
    p('Chimney',(4,9,4),(0,14,-64),(43,40,38),848)
    p('BurnPrompt',(4,.3,3),(0,1,-55),(53,45,38),1088)
    p('ExitDoor',(9.5,12,1),(0,6,50),WOOD,512)
    for x in (-3,3):p('DoorIron',(.4,11,.2),(x,6,49.4),IRON,1088,collide=False)
    p('ExitPrompt',(1,1,1),(0,3,46),(100,100,100),256,transparency=1,collide=False)
    p('LobbySpawn',(6,.25,6),(0,.25,76),(54,57,50),800,spawn=True,transparency=1)
    # Hiding closets: one in each wing, usable through explicit prompts.
    for i,(x,z,angle) in enumerate([(-55,-16,0),(55,-16,0),(-20,40,180),(45,12,0)]):
        p('Wardrobe'+str(i),(5,11,4),(x,5.5,z),(34,29,27),512,(0,angle,0))
        p('HidePrompt'+str(i),(1,1,1),(x,4,z+4.5),(0,0,0),256,transparency=1,collide=False)
        markers.append(dict(name='Hide'+str(i),pos=(x,3.4,z+4.5),kind='Hide'))
    for i,(x,z) in enumerate([(-35,-43),(-22,-18),(24,-18),(44,-39),(-38,24),(-49,42),(35,33),(51,19),(-44,0),(43,0),(7,-37),(-7,30)]):
        height=4.9 if i==0 else (4.6 if i in (3,4,6) else 1.4)
        if i==1:z=-15
        markers.append(dict(name='Loot'+str(i),pos=(x,height,z),kind='Loot'))
    for i,(x,z) in enumerate([(0,36),(0,0),(0,-38),(-36,-28),(36,-28),(-36,28),(36,28),(-43,0),(43,0),(0,-56)]):
        markers.append(dict(name='Patrol'+str(i),pos=(x,3.8,z),kind='Patrol'))
    # Moulding and old portraits add depth in flashlight illumination.
    for z in (-35,-20,20,35):
        p('PortraitFrame',(.4,5,3.6),(-10.9,9,z),(82,65,38),512)
        p('PortraitCanvas',(.45,4.4,3),(-10.6,9,z),(29,28,25),1312)
        p('PortraitSilhouette',(.47,2.6,1.2),(-10.5,8.7,z),(12,13,13),256,collide=False)
        p('PortraitHead',(.5,1.1,.85),(-10.45,10,z),(45,43,35),256,shape='Ball',collide=False)
    for i in range(20):
        x,z=rng.uniform(-8,8),rng.uniform(-44,44)
        p('DustPatch',(rng.uniform(.5,2),.012,rng.uniform(1,3)),(x,.15,z),(36,32,28),1312,collide=False)
    label('ChapelSign','CHAPEL',(-18,12,-7.3),(10,2,.2))
    label('WardSign','WARD',(18,12,-7.3),(10,2,.2))
    label('KitchenSign','KITCHEN',(-18,12,8.7),(10,2,.2))
    label('ArchiveSign','ARCHIVES',(18,12,8.7),(10,2,.2))
    label('FurnaceSign','ASH CHAMBER',(0,13,-49),(10,2,.2))
    label('GateSign','THE LAST EMBER',(0,16,51),(19,3,.3))
    return parts,lights,signs,markers
