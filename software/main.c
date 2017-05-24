#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <sys/mman.h>
#include "hwlib.h"
#include "socal/socal.h"
#include "socal/hps.h"
#include "socal/alt_gpio.h"
#include "hps_0.h"
//#include "led.h"
//#include "seg7.h"
#include <stdbool.h>
#include <pthread.h>

#define HW_REGS_BASE ( ALT_STM_OFST )
#define HW_REGS_SPAN ( 0x04000000 )
#define HW_REGS_MASK ( HW_REGS_SPAN - 1 )


//setting for the HPS2FPGA AXI Bridge
#define ALT_AXI_FPGASLVS_OFST (0xC0000000) // axi_master
#define HW_FPGA_AXI_SPAN (0x40000000) // Bridge span 1GB
#define HW_FPGA_AXI_MASK ( HW_FPGA_AXI_SPAN - 1 )

volatile unsigned long *h2p_lw_output_addr=NULL;
volatile unsigned long *h2p_lw_input_addr=NULL;


int main(int argc, char **argv)
{
	pthread_t id;
	int ret;
	void *virtual_base;
    void *axi_virtual_base;
	int fd;
	// map the address space for the LED registers into user space so we can interact with them.
	// we'll actually map in the entire CSR span of the HPS since we want to access various registers within that span
	if( ( fd = open( "/dev/mem", ( O_RDWR | O_SYNC ) ) ) == -1 ) {
		printf( "ERROR: could not open \"/dev/mem\"...\n" );
		return( 1 );
	}
	virtual_base = mmap( NULL, HW_REGS_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd, HW_REGS_BASE );	
	if( virtual_base == MAP_FAILED ) {
		printf( "ERROR: mmap() failed...\n" );
		close( fd );
		return(1);
	}
    axi_virtual_base = mmap( NULL, HW_FPGA_AXI_SPAN, ( PROT_READ | PROT_WRITE ), MAP_SHARED, fd,ALT_AXI_FPGASLVS_OFST );
    if( axi_virtual_base == MAP_FAILED ) {
		printf( "ERROR: axi mmap() failed...\n" );
		close( fd );
		return( 1 );
    }
	h2p_lw_input_addr=virtual_base + ( ( unsigned long  )( ALT_LWFPGASLVS_OFST +  PIO_INPUT_BASE ) & ( unsigned long)( HW_REGS_MASK ) );
    h2p_lw_output_addr=virtual_base + ( ( unsigned long )( ALT_LWFPGASLVS_OFST +LED_OUTPUT_BASE ) & ( unsigned long)(  HW_REGS_MASK ) );


    int stage=0;
    //printf("Value: %x\n",(*(uint32_t *)h2p_lw_input_addr));
	while(1)
	{
        if(stage==0){
            alt_write_word(h2p_lw_output_addr, UINT32_C(0x00000001) );  //0:ligh, 1:unlight
            stage=1;
        }
        else if(stage==1){
            if( (*(uint32_t *)h2p_lw_input_addr)==UINT32_C(0x00020000)){
                 alt_write_word(h2p_lw_output_addr, UINT32_C(0x00000002) );
                stage=2;
            }
        }
        else if(stage==2){
            uint32_t temp=(*(uint32_t *)h2p_lw_input_addr);
            if(temp>>16==3){
                printf("%x\n",temp&0xffff);
                stage=0;
            }
        }               
	}

	if( munmap( virtual_base, HW_REGS_SPAN ) != 0 ) {
		printf( "ERROR: munmap() failed...\n" );
		close( fd );
		return( 1 );

	}

    
	close( fd );
	return 0;
}
