#!python3

import time
import gpiod
from glob import glob

if __name__ == "__main__":

    gpiolineName = None # "SODIMM_55" - Example of pin A0 on Aster Carrier Board
    gpioChip = None # "/dev/gpiochip0"  - Example of pin A0 on Aster Carrier Board

    if (gpiolineName == None) or (gpioChip == None):
        for gpioChip in glob("/dev/gpiochip*"):
            chip = gpiod.Chip(gpioChip)
            print(f"\n{chip.name()} - {chip.num_lines()} lines")
            
            for line_offset in range(chip.num_lines()):
                line = chip.get_line(line_offset)
                line_name = line.name()
                if line_name == None:
                    line_name = "unnamed  "

                if line.is_used():
                    line_consumer = line.consumer()
                else: 
                    line_consumer = "unused"

                if line.direction() == "1":
                    line_direction = "input"
                else:  
                    line_direction = "output"
                print(f"Line {line_offset:<2}:  {line_name:<15}  {line_consumer:<20}  {line_direction:<10}")

                #line_is_open_source = line.is_open_source()
                #line_is_open_drain = line.is_open_drain()

                line.release()
    else:
        gpioline = gpiod.find_line(gpiolineName)

        if gpioline is None:
            print("Invalid line name.")
        else:
            gpioline.request(consumer="GPIO application", type=gpiod.LINE_REQ_DIR_OUT)
            while True:
                gpioline.set_value(0)
                time.sleep(1)
                gpioline.set_value(1)
                time.sleep(1)
