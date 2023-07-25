# Discrete Fourier Transform for music note recognition in synthesizable Verilog

## Intro

This is a remake of a project I made in 2021 as a part of an music transcription app. When I made it, I used a linear approximation of sine to perform the transform. As you can imagine, it was inconsistent. This version uses parabolic approximation which should give a better transcription.

## Addressing Challanges

There were two main challanges I faced in this project:

1. Representation of float.
2. Implementation of sine.

[Verilog](https://www.tutorialspoint.com/vlsi_design/vlsi_design_verilog_introduction.htm) is a hardware description language. It carries data with wires and buses (collection of wires), with each wire storing either 0 or 1. Of course, I could have used floating point representation just like our computers, however, implementing floating point arithmetic was proven to be a greater challenge. 

My decision at the end is scaling all 'troublesome' numbers (you will see) by $2^{24}$ and rounding it to an integer, which should provide a good amount of precision for most of the use cases.

Sine is also tricky, but I will demonstrate how to arrive at a good approximation below.


## Limitations

This DFT only works with 44.1kHz sample rate audios (it will still produce a result for other sample rates, but the results will be either pitched up or down). This is due to the requirement for pre-caculation due to verilog's limited ability to perform division. Which also means, adding a division module can provide a lot more freedom to this module (potentially turning this into a general purpose DFT).

The output inverval can be any power of 2 seconds (0.25s, 0.5s, 1s, 2s...). But the shorter the inverval is, the more inaccurate the DFT is. This parameter can be used to adapt to the pace of the music.

The period of sine has to be rounded to an integer, and thus for higher frequencies notes the sine will be out of sync as the transform goes on.

Another major downside with this approach is that it uses a lot wires to store various data. A lot of other restrictions must be added to control the number of wires required, for example: the analog input wave must also be adjusted to be between [-1000, 1000].

## Set Up


### Scaler: 

$\gamma = 2^{24}$

### Input sample rate: 

$\omega = 44,100 \text{ Hz}$ (Most common sample rate)

### Output frequency (# of samples/output):

$\omega' = \omega \cdot 2^{-p + 1}$

${p}$ = output inverval adjustment 

1 => 1 output / second

2 => 2 outputs / second

3 => 4 outputs / second

4 => 8 outputs / second (limit)



## Calculations

Let's start with [DFT](https://pythonnumericalmethods.berkeley.edu/notebooks/chapter24.02-Discrete-Fourier-Transform.html):

$ \mathcal{F}_k(x) = \sum_{n=0}^{N-1} x_n [\cos(\frac{2\pi k n}{N}) - i \cdot \sin(\frac{2\pi k n}{N})]$

where $N$ is number of samples per output (${\omega'}$), and $k$ is each individual note's frequency. To address challenge 1, we have to take care of the arguments in sine and cosine. Using a [parabolic approximation](http://datagenetics.com/blog/july12019/index.html), we can arrive at:

$\sin(\frac{2\pi k n}{N}) \approx a [\frac{2\pi k n}{N}] ^ 2 + b [\frac{2\pi k n}{N}]+ c = a[\frac{4\pi^2 k^2 n^2}{N^2}] + b[\frac{2\pi k n}{N}] + c = a' n^2 + b'n + c$

for $ 0 \leq n \leq \frac{N}{2k}$, where:

$a' = -[\frac{60(12-\pi^2)}{\pi^5}]\cdot[\frac{4\pi^2 k^2}{(\omega \cdot 2^{-p+1})^2}] = -[\frac{60(12-\pi^2)}{\pi^3}]\cdot[\frac{k^2}{\omega^2}] \cdot 2^{2p}$

$b' = [\frac{60(12-\pi^2)}{\pi^4}]\cdot[\frac{2\pi k}{\omega\cdot 2^{-p+1}}] =  [\frac{60(12-\pi^2)}{\pi^3}]\cdot[\frac{k}{\omega}] \cdot  2^{p}$

$c = -[\frac{12(10-\pi^2)}{\pi^3}]$

if we fix $\omega = 44,100$, then everything inside square brackets for $a',b',c$ can be pre-determined for all $k$. The $2^p$ part can be dealt with by performing a p-bits bit shift to the left, after scalling the value by $\gamma$. This can be done in verilog during execution.

We can now implement the sine function as it is, but, because we need to undo the scaling eventually, it would be better to multiply the result by $x_n$ before we unscale, as it preserves more precision. So, we define a helper function `sinx` that combines sine and $x_n$:

```v
module sinx(input signed [10:0] xn, input [9:0] n, input [26:0] ya, input [26:0] yb, input [26:0] yc, output signed [10:0] out);
    // compute n^2
    wire [19:0] nsqr = n * n;
    // approximate sign
    wire signed [24:0] sin = -ya * nsqr + yb * n - yc;
    // multiply by x_n
    wire signed [34:0] product = sin * xn;
    // obtain output
    assign out = product[34:24];
endmodule
```
The size of the buses are determined as follows:

- $x_n$: range $[-1000, 1000]$ means $lg(1000) < 10$, so $10$ bit $+ 1$ sign bit is enough.
- $n$: we need to manually control $n$ to be between $0$ and $\frac{N}{2k}$, the maximum value in this case would be the lowest note A0 (smallest $k$): $lg(\frac{44100}{2\cdot 27.5}) < 10$.
- $\gamma a'$, $\gamma b'$, $\gamma c$: after precalculation, the largest value is $C8$'s $\gamma b'$, which is $6,565,132$, which takes $23$ bits to store. With the potential of being shifted $4$ times, $27$ bits is required to store these.
- $sin$: should stay between $-1$ and $1$. After being scaled by $2^{24}$, $24 + 1$ sign bit is enough.

$out$ will unscale the product by taking the most significant $11$ bits (or in other sense, shifting right $24$ bits).

## Data Flow

$x_n$ is simple: it can be connected directly from DFT module input. 

$n$, however, is not as simple: the approximation requires $n$ to be controlled between $0$ and $\frac{N}{2k}$. And because synthesizable Verilog does not allow division, we need to manually keep track of and reset $n$ whenever it gets too big for every $k$. To do this, we will use an $(10+1) \times 88$ (notes) $= 968$ bits wide bus to store all counters (you will see why I included 1 extra bit in just a moment).

We also need to store $\gamma a'$ and $\gamma b'$ for all $k$, this requires two more $27 \times 88 = 2376$ bit long bus. And we can store $\gamma c$ in a $27$ bit long bus since it is the same for all notes.

There is one extra bus we need to store the $\frac{N}{k}$ values to reset $n$ (see next section). This requires $11 \times 88 = 968$ bits.

As for output, we need to add them up. Employing similar strategy, we can store each individual sum in one big bus. My estimation is that $27$ bits should be enough, so our busses will be $27 \times 88 = 2376$ bits long. That can be subjected to optimization.

We do want to perform DFT for all frequencies $k$ simutaneously for speed and to avoid repeating inputs. To do so, we can utilize the `generate` block to instantiate all the sinx modules and the summation modules/registers.

## n Adjustments

As mentioned earlier, $n$ has to be controlled between $0$ and $\frac{N}{2k}$ for the approximation. We can just reset $n$ to $0$ whenever it goes over. But recall that sine's period is actually $\frac{N}{k}$. So the strategy I end up using of is resetting $n$ when it goes over $\frac{N}{k}$ (hence, the one extra bit), and during the second half of the period ($n > \frac{N}{2k}$), subtract $\frac{N}{2k}$ from $n$ and negate the output from sinx. This should give us a decent imitation of sine's periodic behaviour.

There's another adjustment: cosine. To compute cosine, we can perform a sine with $n$ increased by quarter period $\frac{N}{4k}$, and we have to be careful that when the adjusted $n$ exceeds $\frac{N}{k}$, we have to bring it back to $0$. 

## Frequency Domain

After summing up sine and cosine, we need to find the absolute value of their sum by adding the squares of the two sums and taking the square root. Because there is no easy way of doing square root, and I am only interested in finding the largest sum (most likely note played), I just performed a bit shift which preserves the highest sum.

## Afterword 

I have included the file with all the modules as well as testbench generation for testing. This project again, is not a general purpose DFT: it has a lot of limitation and is designed to perform note recognition. It does have to potential to be a general purpose DFT if a division module is implemented so that the coefficients can be calculated in real time and don't require a large amout of wires.

Thank you so much for being here, have a nice day

---

Shawn Lu, 2023

